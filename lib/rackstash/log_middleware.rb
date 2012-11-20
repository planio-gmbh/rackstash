module Rackstash
  class LogMiddleware

    def initialize(app)
      @app = app
    end

    def call(env)
      Rackstash.with_log_buffer do
        begin
          request = Rack::Request.new(env)
          status, headers, result = @app.call(env)
        ensure
          set_fields(request, status)
        end
      end
    end

    protected
    def set_fields(request, status)
      fields = {
        :method => request.request_method,
        :scheme => request.scheme,
        :path => (request.fullpath rescue "unknown"),
        :status => status
      }

      Rackstash.logger.fields.reverse_merge!(fields)
    end
  end
end