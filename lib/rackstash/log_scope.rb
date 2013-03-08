module Rackstash
  module LogScope
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def with_log_buffer(&block)
         push_buffer
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
        flush_and_pop_buffer
      end

    protected
      def push_buffer
        Rackstash.logger.push_buffer
      end

      def flush_and_pop_buffer
        Rackstash.logger.flush_and_pop_buffer
      end
    end
  end
end
