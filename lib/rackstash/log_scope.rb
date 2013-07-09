module Rackstash
  module LogScope
    def with_log_buffer(&block)
       Rackstash.logger.push_buffer
       yield
    rescue Exception => exception
      # Add some details about an exception to the logs
      # This won't catch errors in Rails requests as they are catched by
      # the ActionController::Failsafe middleware before our middleware.
      fields = {
        :error => exception.class.name,
        :error_message => exception.message,
        :error_trace => exception.backtrace.join("\n")
      }
      Rackstash.logger.fields.reverse_merge!(fields) if Rackstash.logger.fields
      raise
    ensure
      Rackstash.logger.flush_and_pop_buffer
    end
  end
end
