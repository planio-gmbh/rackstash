module Rackstash
  module LogScope
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def with_log_buffer(&block)
         push_buffer
         yield
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