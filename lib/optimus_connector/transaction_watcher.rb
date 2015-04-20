require "optimus_connector/connector"
require "optimus_connector/logger"

module OptimusConnector
  class TransactionWatcher
    ENV_KEY = %w(CONTENT_LENGTH AUTH_TYPE GATEWAY_INTERFACE
    PATH_TRANSLATED REMOTE_HOST REMOTE_IDENT REMOTE_USER REMOTE_ADDR
    REQUEST_METHOD SERVER_NAME SERVER_PORT SERVER_PROTOCOL REQUEST_URI PATH_INFO
    HTTP_X_REQUEST_START HTTP_X_MIDDLEWARE_START HTTP_X_QUEUE_START
    HTTP_X_QUEUE_TIME HTTP_X_HEROKU_QUEUE_WAIT_TIME HTTP_X_APPLICATION_START
    HTTP_ACCEPT HTTP_ACCEPT_CHARSET HTTP_ACCEPT_ENCODING HTTP_ACCEPT_LANGUAGE
    HTTP_CACHE_CONTROL HTTP_CONNECTION HTTP_USER_AGENT HTTP_FROM HTTP_NEGOTIATE
    HTTP_PRAGMA HTTP_REFERER HTTP_X_FORWARDED_FOR HTTP_CLIENT_IP)

    # override process_action to add session and environment info to the payload
    ActionController::Instrumentation.send(:define_method, "process_action") do |arg|
      raw_payload = {
          controller: self.class.name,
          action: self.action_name,
          params: request.filtered_parameters,
          formats: request.formats.map(&:to_sym),
          method: request.method,
          path: (request.fullpath rescue "unknown"),
          session: request.session,
          environment: request.env
      }

      ActiveSupport::Notifications.instrument("start_processing.action_controller", raw_payload.dup)
      ActiveSupport::Notifications.instrument("process_action.action_controller", raw_payload) do |payload|
        result = super(arg)
        payload[:status] = response.status
        append_info_to_payload(payload)
        result
      end
    end


    def initialize
      ActiveSupport::Notifications.subscribe("start_processing.action_controller", &method(:before_http_request))
      ActiveSupport::Notifications.subscribe("sql.active_record", &method(:after_sql_query))
      ActiveSupport::Notifications.subscribe("process_action.action_controller", &method(:after_http_request))
      ActiveSupport::Notifications.subscribe("render_template.action_view", &method(:after_view_rendering))
      ActiveSupport::Notifications.subscribe("render_partial.action_view", &method(:after_partial_rendering))
      # make sure to set config.active_support.deprecation to :notify in production.rb
      ActiveSupport::Notifications.subscribe("deprecation.rails", &method(:after_deprecation_warning))
      ActionController::Base.rescue_from(StandardError, &method(:after_exception))
    end


    def before_http_request(_name, start, _finish, _id, payload)
      reset_transaction
      Thread.current[:request] = {
          time: start,
          controller: payload[:controller],
          action: payload[:action],
          path: payload[:path],
          params: filter_request_params(payload[:params]),
          format: payload[:format],
          method: payload[:method],
          session: payload[:session],
          environment: clean_request_env(payload[:environment])
      }
    end

    def after_sql_query(_name, start, finish, _id, payload)
      if is_query_app_relevant?(payload[:name])
        file, line, method = extract_file_and_line_from_call_stack(caller)
        query = {
            name: payload[:name],
            sql: payload[:sql],
            runtime: compute_duration(start, finish),
            triggered_from: {
                file: file,
                line: line,
                method: method
            }
        }
        if Thread.current[:queries]
          Thread.current[:queries] << query
        else
          OptimusConnector.connector.enqueue!("/push/non_web_requests", query)
        end
      end
    rescue => exception
      Logger.log(exception)
    end

    def after_view_rendering(name, start, finish, id, payload)
      Thread.current[:views] << {
          file: relative_path(payload[:identifier]),
          runtime: compute_duration(start, finish)
      }
    end
    alias_method :after_partial_rendering, :after_view_rendering

    def after_exception(exception)
      file, line = exception.backtrace.first.split(":")
      Thread.current[:error] = {
          exception: exception.class.to_s,
          backtrace: exception.backtrace,
          message: exception.message,
          file: relative_path(file),
          line: line.to_i
      }
      raise exception
    end

    def after_http_request(_name, start, finish, _id, payload)
      Thread.current[:request].merge!(status: payload[:status])
      db_runtime = payload[:db_runtime] || 0
      view_runtime = payload[:view_runtime] || 0
      summary = {
          db_runtime: db_runtime,
          view_runtime: view_runtime || 0,
          other_runtime: compute_duration(start, finish) - db_runtime - view_runtime
      }

      transaction = {request: Thread.current[:request], summary: summary, breakdown: {queries: Thread.current[:queries], views: Thread.current[:views]}, error: Thread.current[:error], warnings: Thread.current[:warnings]}
      OptimusConnector.connector.enqueue!("/push/web_requests", transaction)
    rescue => exception
      Logger.log(exception)
    end


    def after_deprecation_warning(_name, start, finish, _id, payload)
      Thread.current[:warnings] << {
          type: "Deprecation",
          message: payload[:message]
      }
    rescue => exception
      log_error(exception)
    end


    #######################
    ### Private methods ###
    #######################

    private

    def reset_transaction
      Thread.current[:request] = {}
      Thread.current[:queries] = []
      Thread.current[:views] = []
      Thread.current[:error] = {}
      Thread.current[:warnings] = []
    end


    def extract_file_and_line_from_call_stack(stack)
      return unless location = stack.find { |str| str.include?(Rails.root.to_s) }
      file, line, method = location.split(":")
      method = cleanup_method_name(method)
      file.sub!(Rails.root.to_s, "")
      [file || 'unknown', line || 0, method || 'unknown']
    end

    def cleanup_method_name(method)
      method.sub!("block in ", "")
      method.sub!("in `", "")
      method.sub!("'", "")
      method.index("_app_views_") == 0 ? nil : method
    end

    def compute_duration(start, finish)
      ((finish - start) * 1000)
    end

    def relative_path(path)
      path.sub(Rails.root.to_s, "")
    end

    def is_query_app_relevant?(query_name)
      !["SCHEMA", "ActiveRecord::SchemaMigration Load"].include? query_name
    end

    def clean_request_env(env)
      # only return interesting env values
      output = {}
      ENV_KEY.each { |k| output[k] = env[k] }
      output
    end

    def filter_request_params(params)
      # filter sensitive params such as password
      @params_filter ||= ActionDispatch::Http::ParameterFilter.new(Rails.application.config.filter_parameters)
      @params_filter.filter(params)
    end
  end
end
