# frozen_string_literal: true

require 'set'
require 'logger'
require 'fileutils'

module RailsActionTracker
  class Tracker
    THREAD_KEY = :rails_action_tracker_logs

    class << self
      attr_accessor :config, :custom_logger

      def configure(options = {})
        @config = {
          print_to_rails_log: true,
          write_to_file: false,
          log_file_path: nil,
          services: [],
          ignored_tables: %w[pg_attribute pg_index pg_class pg_namespace pg_type ar_internal_metadata
                             schema_migrations],
          ignored_controllers: [],
          ignored_actions: {}
        }.merge(options)

        setup_custom_logger if @config[:write_to_file] && @config[:log_file_path]
      end

      def start_tracking
        Thread.current[THREAD_KEY] = {
          read: Set.new,
          write: Set.new,
          captured_logs: [],
          controller: nil,
          action: nil
        }
        subscribe_to_sql_notifications
        subscribe_to_logger
      end

      def stop_tracking
        unsubscribe_from_sql_notifications
        unsubscribe_from_logger
        logs = Thread.current[THREAD_KEY] || { read: Set.new, write: Set.new, captured_logs: [], controller: nil,
                                               action: nil }
        Thread.current[THREAD_KEY] = nil
        logs
      end

      def print_summary
        logs = Thread.current[THREAD_KEY]
        return unless logs

        # Check if this controller/action should be ignored
        return if should_ignore_controller_action?(logs[:controller], logs[:action])

        services_accessed = detect_services(logs[:captured_logs])
        read_models = logs[:read].to_a.uniq.sort
        write_models = logs[:write].to_a.uniq.sort

        controller_action = "#{logs[:controller]}##{logs[:action]}" if logs[:controller] && logs[:action]

        # Generate outputs with and without colors
        colored_output = format_summary(read_models, write_models, services_accessed, controller_action, true)
        plain_output = format_summary(read_models, write_models, services_accessed, controller_action, false)

        log_output(colored_output, plain_output)
      end

      private

      def should_ignore_controller_action?(controller, action)
        return false unless config && controller && action

        # Check if entire controller is ignored
        ignored_controllers = config[:ignored_controllers] || []
        return true if ignored_controllers.include?(controller)

        # Check if specific controller#action combination is ignored
        ignored_actions = config[:ignored_actions] || {}
        controller_actions = ignored_actions[controller] || []
        return true if controller_actions.include?(action)

        false
      end

      def setup_custom_logger
        return unless config[:log_file_path]

        log_dir = File.dirname(config[:log_file_path])
        FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)

        @custom_logger = Logger.new(config[:log_file_path])
        @custom_logger.formatter = proc do |severity, datetime, _progname, msg|
          "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
        end
      end

      def log_query(sql)
        logs = Thread.current[THREAD_KEY]
        return unless logs

        return unless (match = sql.match(/(FROM|INTO|UPDATE|INSERT INTO)\s+["']?(\w+)["']?/i))

        table = match[2]

        # Skip ignored tables (case insensitive)
        ignored_tables = config&.dig(:ignored_tables) || %w[pg_attribute pg_index pg_class pg_namespace
                                                            pg_type ar_internal_metadata schema_migrations]
        return if ignored_tables.map(&:downcase).include?(table.downcase)

        if sql =~ /\A\s*SELECT/i
          logs[:read] << table
        else
          logs[:write] << table
        end
      end

      def log_message(message)
        logs = Thread.current[THREAD_KEY]
        return unless logs

        logs[:captured_logs] << message
      end

      def detect_services(captured_logs)
        services_accessed = []
        default_service_patterns = [
          { name: 'Pusher', pattern: /pusher/i },
          { name: 'Honeybadger', pattern: /honeybadger/i },
          { name: 'Redis', pattern: /redis/i },
          { name: 'Sidekiq', pattern: /sidekiq/i },
          { name: 'ActionMailer', pattern: /mail|email/i },
          { name: 'HTTP', pattern: /http|api/i }
        ]

        service_patterns = config&.dig(:services) || default_service_patterns

        captured_logs.each do |line|
          service_patterns.each do |service_config|
            if service_config.is_a?(Hash)
              services_accessed << service_config[:name] if line.match?(service_config[:pattern])
            elsif service_config.is_a?(String)
              services_accessed << service_config if line.downcase.include?(service_config.downcase)
            end
          end
        end

        services_accessed.uniq
      end

      # rubocop:disable Style/OptionalBooleanParameter
      def format_summary(read_models, write_models, services, controller_action = nil, colorize = true)
        if colorize && defined?(Rails) && Rails.logger.respond_to?(:colorize_logging) && Rails.logger.colorize_logging
          # Use Rails default colors when available
          green = defined?(ActiveSupport::LogSubscriber::GREEN) ? ActiveSupport::LogSubscriber::GREEN : "\e[32m"
          red = defined?(ActiveSupport::LogSubscriber::RED) ? ActiveSupport::LogSubscriber::RED : "\e[31m"
          blue = defined?(ActiveSupport::LogSubscriber::BLUE) ? ActiveSupport::LogSubscriber::BLUE : "\e[34m"
          yellow = defined?(ActiveSupport::LogSubscriber::YELLOW) ? ActiveSupport::LogSubscriber::YELLOW : "\e[33m"
          reset = defined?(ActiveSupport::LogSubscriber::CLEAR) ? ActiveSupport::LogSubscriber::CLEAR : "\e[0m"
        else
          green = red = blue = yellow = reset = ''
        end

        max_rows = [read_models.size, write_models.size, services.size].max

        if max_rows.zero?
          header = controller_action ? "#{yellow}#{controller_action}#{reset}: " : ''
          return "#{header}No models or services accessed during this request.\n"
        end

        read_models += [''] * (max_rows - read_models.size)
        write_models += [''] * (max_rows - write_models.size)
        services += [''] * (max_rows - services.size)

        # Calculate dynamic column widths
        read_width = [read_models.map(&:length).max || 0, 'Models Read'.length].max
        write_width = [write_models.map(&:length).max || 0, 'Models Written'.length].max
        services_width = [services.map(&:length).max || 0, 'Services Accessed'.length].max

        # Create separator line
        separator = "+#{'-' * (read_width + 2)}+#{'-' * (write_width + 2)}+#{'-' * (services_width + 2)}+"

        header = controller_action ? "#{yellow}#{controller_action}#{reset} - " : ''
        table = "#{header}Models and Services accessed during request:\n"
        table += "#{separator}\n"
        table += "| #{green}#{'Models Read'.ljust(read_width)}#{reset} | #{red}#{'Models Written'.ljust(write_width)}#{reset} | " \
                 "#{blue}#{'Services Accessed'.ljust(services_width)}#{reset} |\n"
        table += "#{separator}\n"
        max_rows.times do |i|
          table += "| #{read_models[i].ljust(read_width)} | #{write_models[i].ljust(write_width)} | #{services[i].ljust(services_width)} |\n"
        end
        table += "#{separator}\n"
        table
      end
      # rubocop:enable Style/OptionalBooleanParameter

      def log_output(colored_output, plain_output)
        if config.nil?
          Rails.logger.info "\n#{colored_output}" if defined?(Rails)
        else
          Rails.logger.info "\n#{colored_output}" if config[:print_to_rails_log] && defined?(Rails)

          custom_logger.info "\n#{plain_output}" if config[:write_to_file] && custom_logger
        end
      end

      def subscribe_to_sql_notifications
        @subscribe_to_sql_notifications ||= ActiveSupport::Notifications
                                            .subscribe('sql.active_record') do |_name, _start, _finish, _id, payload|
          sql = payload[:sql]
          log_query(sql) unless sql.include?('SCHEMA')
        end
      end

      def unsubscribe_from_sql_notifications
        ActiveSupport::Notifications.unsubscribe(@sql_subscriber) if @sql_subscriber
        @sql_subscriber = nil
      end

      def subscribe_to_logger
        return unless defined?(Rails)

        @subscribe_to_logger ||= ActiveSupport::Notifications.subscribe(/.*/) do |name, _start, _finish, _id, payload|
          next if name.include?('sql.active_record')

          # Capture controller and action information
          if name == 'process_action.action_controller'
            logs = Thread.current[THREAD_KEY]
            if logs
              logs[:controller] = payload[:controller]
              logs[:action] = payload[:action]
            end
          end

          message = case name
                    when 'process_action.action_controller'
                      "Controller: #{payload[:controller]}##{payload[:action]}"
                    when 'render_template.action_view'
                      "Template: #{payload[:identifier]}"
                    else
                      payload.to_s
                    end

          log_message(message) if message && !message.empty?
        end
      end

      def unsubscribe_from_logger
        ActiveSupport::Notifications.unsubscribe(@logger_subscriber) if @logger_subscriber
        @logger_subscriber = nil
      end
    end
  end
end
