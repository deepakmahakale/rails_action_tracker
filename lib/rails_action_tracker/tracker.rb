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
          print_format: :table,
          log_format: nil,
          services: [],
          ignored_tables: %w[pg_attribute pg_index pg_class pg_namespace pg_type ar_internal_metadata
                             schema_migrations],
          ignored_controllers: [],
          ignored_actions: {}
        }.merge(options)

        # Default log_format to print_format if not specified
        @config[:log_format] ||= @config[:print_format]

        # Only setup custom logger for formats that don't write directly to file
        should_setup_logger = @config[:write_to_file] && @config[:log_file_path] &&
                              !%i[json csv].include?(@config[:log_format])
        setup_custom_logger if should_setup_logger
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
        return if should_ignore_controller_action?(logs[:controller], logs[:action])

        summary_data = prepare_summary_data(logs)
        handle_print_output(summary_data)
        handle_log_file_output(summary_data)
      end

      private

      def should_ignore_controller_action?(controller, action)
        return false unless config && controller && action

        # Check if entire controller is ignored
        ignored_controllers = config[:ignored_controllers] || []
        return true if ignored_controllers.include?(controller)

        # Check controller-specific action ignores
        ignored_actions = config[:ignored_actions] || {}

        # Handle flexible controller/action filtering
        ignored_actions.each do |pattern_controller, actions|
          # Match controller name (exact match or empty string for all controllers)
          next unless pattern_controller.empty? || pattern_controller == controller

          # If actions is empty array or nil, ignore entire controller
          return true if actions.nil? || (actions.is_a?(Array) && actions.empty?)

          # Check specific actions
          return true if actions.is_a?(Array) && actions.include?(action)
        end

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

      def prepare_summary_data(logs)
        services_accessed = detect_services(logs[:captured_logs])
        read_models = logs[:read].to_a.uniq.sort
        write_models = logs[:write].to_a.uniq.sort
        controller_action = "#{logs[:controller]}##{logs[:action]}" if logs[:controller] && logs[:action]

        {
          read_models: read_models,
          write_models: write_models,
          services_accessed: services_accessed,
          controller_action: controller_action
        }
      end

      def handle_print_output(summary_data)
        return unless config&.dig(:print_to_rails_log)

        print_format = config&.dig(:print_format) || :table
        print_colored_output, print_plain_output = generate_format_output(
          print_format, summary_data, true
        )
        log_output(print_colored_output, print_plain_output)
      end

      def handle_log_file_output(summary_data)
        return unless config&.dig(:write_to_file) && config[:log_file_path]

        log_format = config&.dig(:log_format) || config&.dig(:print_format) || :table
        process_log_file_format(log_format, summary_data)
      end

      def process_log_file_format(log_format, summary_data)
        case log_format
        when :json
          accumulate_json_data(
            summary_data[:read_models],
            summary_data[:write_models],
            summary_data[:services_accessed],
            summary_data[:controller_action]
          )
        when :csv
          accumulate_csv_data(
            summary_data[:read_models],
            summary_data[:write_models],
            summary_data[:services_accessed],
            summary_data[:controller_action]
          )
        else
          _, log_plain_output = generate_format_output(log_format, summary_data, false)
          custom_logger&.info(log_plain_output)
        end
      end

      # rubocop:disable Style/OptionalBooleanParameter
      def format_table_summary(read_models, write_models, services, controller_action = nil, colorize = true)
        colors = setup_colors(colorize)
        max_rows = [read_models.size, write_models.size, services.size].max

        return format_empty_summary(controller_action, colors) if max_rows.zero?

        padded_arrays = pad_arrays_to_max_length(read_models, write_models, services, max_rows)
        column_widths = calculate_column_widths(padded_arrays[:read], padded_arrays[:write], padded_arrays[:services])

        build_table(padded_arrays, column_widths, controller_action, colors, max_rows)
      end
      # rubocop:enable Style/OptionalBooleanParameter

      def format_csv_summary(read_models, write_models, services, controller_action = nil)
        if read_models.empty? && write_models.empty? && services.empty?
          return "Action\nNo models or services accessed during this request.\n"
        end

        # Get all unique table names and service names
        all_tables = (read_models + write_models).uniq.sort
        all_services = services.uniq.sort

        # Create header
        header = ['Action'] + all_tables + all_services
        csv_output = "#{header.join(',')}\n"

        # Create data row
        action_name = controller_action || 'Unknown'
        row = [action_name]

        # Add table columns (R for read, W for write, RW for both, - for none)
        all_tables.each do |table|
          row << if read_models.include?(table) && write_models.include?(table)
                   'RW'
                 elsif read_models.include?(table)
                   'R'
                 elsif write_models.include?(table)
                   'W'
                 else
                   '-'
                 end
        end

        # Add service columns (Y for accessed, - for not accessed)
        all_services.each do |service|
          row << (services.include?(service) ? 'Y' : '-')
        end

        csv_output += "#{row.join(',')}\n"
        csv_output
      end

      def format_json_summary(read_models, write_models, services, controller_action = nil)
        require 'json'

        action_name = controller_action || 'Unknown'

        result = {
          action_name => {
            'read' => read_models.uniq.sort,
            'write' => write_models.uniq.sort,
            'services' => services.uniq.sort
          }
        }

        JSON.pretty_generate(result)
      end

      def format_json_print_summary(read_models, write_models, services, controller_action = nil)
        require 'json'

        action_name = controller_action || 'Unknown'

        # For printing, show only current action's data in a clean format
        result = {
          'read' => read_models.uniq.sort,
          'write' => write_models.uniq.sort,
          'services' => services.uniq.sort
        }

        "#{action_name}: #{JSON.pretty_generate(result)}"
      end

      def format_csv_print_summary(read_models, write_models, services, controller_action = nil)
        if read_models.empty? && write_models.empty? && services.empty?
          action_name = controller_action || 'Unknown'
          return "#{action_name}: No models or services accessed during this request."
        end

        # Get all unique table names and service names for this action only
        all_tables = (read_models + write_models).uniq.sort
        all_services = services.uniq.sort

        # Create header
        header = ['Action'] + all_tables + all_services
        csv_output = "#{header.join(',')}\n"

        # Create data row
        action_name = controller_action || 'Unknown'
        row = [action_name]

        # Add table columns (R for read, W for write, RW for both, - for none)
        all_tables.each do |table|
          row << if read_models.include?(table) && write_models.include?(table)
                   'RW'
                 elsif read_models.include?(table)
                   'R'
                 elsif write_models.include?(table)
                   'W'
                 else
                   '-'
                 end
        end

        # Add service columns (Y for accessed, - for not accessed)
        all_services.each do |service|
          row << (services.include?(service) ? 'Y' : '-')
        end

        csv_output += "#{row.join(',')}\n"
        csv_output
      end

      def generate_format_output(format, summary_data, colorize)
        read_models = summary_data[:read_models]
        write_models = summary_data[:write_models]
        services = summary_data[:services_accessed]
        controller_action = summary_data[:controller_action]

        case format
        when :csv
          output = format_csv_print_summary(read_models, write_models, services, controller_action)
          [output, output]
        when :json
          output = format_json_print_summary(read_models, write_models, services, controller_action)
          [output, output]
        else
          colored_output = format_table_summary(read_models, write_models, services, controller_action, colorize)
          plain_output = format_table_summary(read_models, write_models, services, controller_action, false)
          [colored_output, plain_output]
        end
      end

      def accumulate_json_data(read_models, write_models, services, controller_action = nil)
        return unless config&.dig(:write_to_file) && config[:log_file_path]

        action_name = controller_action || 'Unknown'
        json_file_path = config[:log_file_path]

        ensure_log_directory_exists(json_file_path)
        update_json_file(json_file_path, action_name, read_models, write_models, services)
      rescue StandardError => e
        Rails.logger.error "Failed to accumulate JSON data: #{e.message}" if defined?(Rails)
      end

      def accumulate_csv_data(read_models, write_models, services, controller_action = nil)
        return unless config&.dig(:write_to_file) && config[:log_file_path]

        action_name = controller_action || 'Unknown'
        csv_file_path = config[:log_file_path]

        ensure_log_directory_exists(csv_file_path)
        update_csv_file(csv_file_path, action_name, read_models, write_models, services)
      rescue StandardError => e
        Rails.logger.error "Failed to accumulate CSV data: #{e.message}" if defined?(Rails)
      end

      def setup_colors(colorize)
        return { green: '', red: '', blue: '', yellow: '', reset: '' } unless colorize
        return default_colors unless rails_colorized?

        {
          green: fetch_rails_color('GREEN', "\e[32m"),
          red: fetch_rails_color('RED', "\e[31m"),
          blue: fetch_rails_color('BLUE', "\e[34m"),
          yellow: fetch_rails_color('YELLOW', "\e[33m"),
          reset: fetch_rails_color('CLEAR', "\e[0m")
        }
      end

      def default_colors
        { green: '', red: '', blue: '', yellow: '', reset: '' }
      end

      def rails_colorized?
        defined?(Rails) && Rails.logger.respond_to?(:colorize_logging) && Rails.logger.colorize_logging
      end

      def fetch_rails_color(color_name, fallback)
        if defined?(ActiveSupport::LogSubscriber.const_get(color_name))
          ActiveSupport::LogSubscriber.const_get(color_name)
        else
          fallback
        end
      end

      def format_empty_summary(controller_action, colors)
        header = controller_action ? "#{colors[:yellow]}#{controller_action}#{colors[:reset]}: " : ''
        "#{header}No models or services accessed during this request.\n"
      end

      def pad_arrays_to_max_length(read_models, write_models, services, max_rows)
        {
          read: read_models + [''] * (max_rows - read_models.size),
          write: write_models + [''] * (max_rows - write_models.size),
          services: services + [''] * (max_rows - services.size)
        }
      end

      def calculate_column_widths(read_models, write_models, services)
        {
          read: [read_models.map(&:length).max || 0, 'Models Read'.length].max,
          write: [write_models.map(&:length).max || 0, 'Models Written'.length].max,
          services: [services.map(&:length).max || 0, 'Services Accessed'.length].max
        }
      end

      def build_table(arrays, widths, controller_action, colors, max_rows)
        separator = build_separator(widths)
        header = controller_action ? "#{colors[:yellow]}#{controller_action}#{colors[:reset]} - " : ''

        table = "#{header}Models and Services accessed during request:\n"
        table += "#{separator}\n"
        table += build_header_row(widths, colors)
        table += "#{separator}\n"
        table += build_data_rows(arrays, widths, max_rows)
        table + "#{separator}\n"
      end

      def build_separator(widths)
        "+#{'-' * (widths[:read] + 2)}+#{'-' * (widths[:write] + 2)}+#{'-' * (widths[:services] + 2)}+"
      end

      def build_header_row(widths, colors)
        read_header = "#{colors[:green]}#{'Models Read'.ljust(widths[:read])}#{colors[:reset]}"
        write_header = "#{colors[:red]}#{'Models Written'.ljust(widths[:write])}#{colors[:reset]}"
        services_header = "#{colors[:blue]}#{'Services Accessed'.ljust(widths[:services])}#{colors[:reset]}"

        "| #{read_header} | #{write_header} | #{services_header} |\n"
      end

      def build_data_rows(arrays, widths, max_rows)
        table = ''
        max_rows.times do |i|
          read_cell = arrays[:read][i].ljust(widths[:read])
          write_cell = arrays[:write][i].ljust(widths[:write])
          services_cell = arrays[:services][i].ljust(widths[:services])
          table += "| #{read_cell} | #{write_cell} | #{services_cell} |\n"
        end
        table
      end

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

      def ensure_log_directory_exists(json_file_path)
        log_dir = File.dirname(json_file_path)
        FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)
      end

      def update_json_file(json_file_path, action_name, read_models, write_models, services)
        File.open(json_file_path, File::RDWR | File::CREAT, 0o644) do |file|
          file.flock(File::LOCK_EX)
          existing_data = read_existing_json_data(file)
          updated_data = merge_action_data(existing_data, action_name, read_models, write_models, services)
          write_json_data(file, updated_data)
        end
      end

      def read_existing_json_data(file)
        require 'json'
        file.rewind # Ensure we're at the beginning of the file
        file_content = file.read.strip
        return {} if file_content.empty?

        JSON.parse(file_content)
      rescue JSON::ParserError
        {}
      end

      def merge_action_data(existing_data, action_name, read_models, write_models, services)
        new_read_models = (read_models || []).uniq.sort
        new_write_models = (write_models || []).uniq.sort
        new_services = (services || []).uniq.sort

        if existing_data[action_name]
          merge_with_existing_action(existing_data, action_name, new_read_models, new_write_models, new_services)
        else
          add_new_action(existing_data, action_name, new_read_models, new_write_models, new_services)
        end

        existing_data
      end

      def merge_with_existing_action(existing_data, action_name, new_read, new_write, new_services)
        existing_read = existing_data[action_name]['read'] || []
        existing_write = existing_data[action_name]['write'] || []
        existing_services = existing_data[action_name]['services'] || []

        existing_data[action_name] = {
          'read' => (existing_read + new_read).uniq.sort,
          'write' => (existing_write + new_write).uniq.sort,
          'services' => (existing_services + new_services).uniq.sort
        }
      end

      def add_new_action(existing_data, action_name, new_read, new_write, new_services)
        existing_data[action_name] = {
          'read' => new_read,
          'write' => new_write,
          'services' => new_services
        }
      end

      def write_json_data(file, data)
        require 'json'
        file.rewind
        file.write(JSON.pretty_generate(data))
        file.truncate(file.pos)
      end

      def update_csv_file(csv_file_path, action_name, read_models, write_models, services)
        File.open(csv_file_path, File::RDWR | File::CREAT, 0o644) do |file|
          file.flock(File::LOCK_EX)
          existing_data = read_existing_csv_data(file)
          updated_data = merge_csv_action_data(existing_data, action_name, read_models, write_models, services)
          write_csv_data(file, updated_data)
        end
      end

      def read_existing_csv_data(file)
        require 'csv'
        file.rewind
        file_content = file.read.strip
        return { headers: ['Action'], rows: {} } if file_content.empty?

        begin
          csv_data = CSV.parse(file_content, headers: true)
          headers = csv_data.headers
          rows = {}

          csv_data.each do |row|
            action = row['Action']
            rows[action] = row.to_h if action
          end

          { headers: headers, rows: rows }
        rescue CSV::MalformedCSVError
          { headers: ['Action'], rows: {} }
        end
      end

      def merge_csv_action_data(existing_data, action_name, read_models, write_models, services)
        cleaned_data = sanitize_csv_inputs(read_models, write_models, services)
        all_combined = build_combined_headers(existing_data, cleaned_data)
        new_headers = ['Action'] + all_combined

        if existing_data[:rows][action_name]
          merge_existing_csv_row(existing_data[:rows][action_name], all_combined, cleaned_data)
        else
          existing_data[:rows][action_name] = create_new_csv_row(action_name, all_combined, cleaned_data)
        end

        existing_data[:headers] = new_headers
        existing_data
      end

      def sanitize_csv_inputs(read_models, write_models, services)
        {
          read_models: (read_models || []).uniq.sort,
          write_models: (write_models || []).uniq.sort,
          services: (services || []).uniq.sort,
          all_tables: ((read_models || []) + (write_models || [])).uniq.sort
        }
      end

      def build_combined_headers(existing_data, cleaned_data)
        existing_headers = existing_data[:headers] || ['Action']
        existing_names = existing_headers[1..] || []
        (cleaned_data[:all_tables] + cleaned_data[:services] + existing_names).uniq.sort
      end

      def merge_existing_csv_row(existing_row, all_combined, cleaned_data)
        all_combined.each do |name|
          if cleaned_data[:all_tables].include?(name)
            current_value = existing_row[name] || '-'
            new_value = determine_table_access(name, cleaned_data[:read_models], cleaned_data[:write_models])
            existing_row[name] = merge_table_access(current_value, new_value)
          elsif cleaned_data[:services].include?(name)
            existing_row[name] = 'Y'
          end
        end
      end

      def create_new_csv_row(action_name, all_combined, cleaned_data)
        new_row = { 'Action' => action_name }
        all_combined.each do |name|
          new_row[name] = if cleaned_data[:all_tables].include?(name)
                            determine_table_access(name, cleaned_data[:read_models], cleaned_data[:write_models])
                          elsif cleaned_data[:services].include?(name)
                            'Y'
                          else
                            '-'
                          end
        end
        new_row
      end

      def determine_table_access(table_name, read_models, write_models)
        read_access = read_models.include?(table_name)
        write_access = write_models.include?(table_name)

        if read_access && write_access
          'RW'
        elsif read_access
          'R'
        elsif write_access
          'W'
        else
          '-'
        end
      end

      def merge_table_access(current, new_access)
        return new_access if current == '-'
        return current if new_access == '-'

        # Convert to sets for easier merging
        current_ops = current == 'RW' ? %w[R W] : [current]
        new_ops = new_access == 'RW' ? %w[R W] : [new_access]

        merged_ops = (current_ops + new_ops).uniq.sort

        case merged_ops
        when %w[R W]
          'RW'
        when ['R']
          'R'
        when ['W']
          'W'
        else
          current
        end
      end

      def write_csv_data(file, data)
        require 'csv'
        file.rewind

        output = CSV.generate do |csv|
          csv << data[:headers]
          data[:rows].each_value do |row|
            csv << data[:headers].map { |header| row[header] || '-' }
          end
        end

        file.write(output)
        file.truncate(file.pos)
      end
    end
  end
end
