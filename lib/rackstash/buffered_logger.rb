require 'securerandom'

module Rackstash
  class BufferedLogger
    extend Forwardable

    module Severity
      Severities = [:DEBUG, :INFO, :WARN, :ERROR, :FATAL, :UNKNOWN]

      Severities.each_with_index do |s,i|
        const_set(s, i)
      end
    end
    include Severity

    def initialize(logger)
      @logger = logger
      @buffer = {}
    end

    attr_reader :logger
    def_delegators :@logger, :level, :level=
    def_delegators :@logger, :silencer, :silencer=, :silence

    # Note: Buffered logs need to be explicitly flushed to the underlying
    # logger using +flush_and_pop_buffer+. This will not flush the underlying
    # logger. If this is required, you still need to call
    # +BufferedLogger#logger.flush+
    def_delegators :@logger, :flush, :auto_flushing, :auto_flushing=

    def add(severity, message = nil, progname = nil, &block)
      return if level > severity
      message = (message || (block && block.call) || progname).to_s

      if buffering?
        buffer[:messages] << {:severity => severity, :message => message.to_s}
        message
      else
        event_message = "[#{Severity::Severities[severity]}] ".rjust(10)
        event_message << message

        event = LogStash::Event.new(
          "@message" => event_message,
          "@fields" => { :log_id => uuid, :pid => Process.pid },
          "@tags" => Rackstash.tags,
          "@source" => Rackstash.source
        )

        logger.add(severity, event.to_json)
      end
    end

    for severity in Severity.constants
      class_eval <<-EOT, __FILE__, __LINE__ + 1
        def #{severity.downcase}(message = nil, progname = nil, &block)  # def debug(message = nil, progname = nil, &block)
          add(#{severity}, message, progname, &block)                    #   add(DEBUG, message, progname, &block)
        end                                                              # end
                                                                         #
        def #{severity.downcase}?                                        # def debug?
          #{severity} >= level                                           #   DEBUG >= level
        end                                                              # end
      EOT
    end

    def fields
      buffer && buffer[:fields]
    end

    def close
      flush_and_pop_buffer while buffering?
      logger.flush if logger.respond_to?(:flush)
      logger.close if logger.respond_to?(:close)
    end

    def push_buffer
      child_buffer = {
        :messages => [],
        :fields => { :log_id => uuid, :pid => Process.pid }
      }

      @buffer[Thread.current] ||= []
      if parent_buffer = @buffer[Thread.current].last
        parent_buffer[:fields][:child_log_ids] ||= []
        parent_buffer[:fields][:child_log_ids] << child_buffer[:fields][:log_id]
        child_buffer[:fields][:parent_log_id] = parent_buffer[:fields][:log_id]
      end

      @buffer[Thread.current] << child_buffer
      nil
    end

    def flush_and_pop_buffer()
      if event = logstash_event
        logger.send(Rackstash.log_level, event)
        logger.flush if logger.respond_to(:flush)
      end

      pop_buffer
    end

    def buffering?
      !!buffer
    end

    protected
    def buffer
      @buffer[Thread.current] && @buffer[Thread.current].last
    end

    # This method removes the top-most buffer.
    # It does not flush the buffer in any way. Use +flush_and_pop_buffer+
    # for that.
    def pop_buffer
      if @buffer[Thread.current]
        unless @buffer[Thread.current].pop
          # We need to delete the whole array to prevent a memory leak
          # from piling threads
          @buffer.delete(Thread.current)
        end
      end
      nil
    end

    # uuid generates a v4 random UUID (Universally Unique IDentifier).
    #
    #    p SecureRandom.uuid #=> "2d931510-d99f-494a-8c67-87feb05e1594"
    #    p SecureRandom.uuid #=> "bad85eb9-0713-4da7-8d36-07a8e4b00eab"
    #    p SecureRandom.uuid #=> "62936e70-1815-439b-bf89-8492855a7e6b"
    #
    # The version 4 UUID is purely random (except the version). It doesn’t
    # contain meaningful information such as MAC address, time, etc.
    #
    # See RFC 4122 for details of UUID.
    def uuid
      if SecureRandom.respond_to?(:uuid)
        # Available since Ruby 1.9.2
        SecureRandom.uuid
      else
        # Copied verbatim from SecureRandom.uuid of MRI 1.9.3
        ary = SecureRandom.random_bytes(16).unpack("NnnnnN")
        ary[2] = (ary[2] & 0x0fff) | 0x4000
        ary[3] = (ary[3] & 0x3fff) | 0x8000
        "%08x-%04x-%04x-%04x-%04x%08x" % ary
      end
    end

    def logstash_event
      return unless buffer = self.buffer

      message = ""
      buffer[:messages].each do |line|
        message << "[#{Severity::Severities[line[:severity]]}] ".rjust(10)
        message << (line[:message][-1] == ?\n ? line[:message] : "#{line[:message]}\n")
      end

      event = LogStash::Event.new(
        "@message" => message,
        "@fields" => buffer[:fields],
        "@tags" => Rackstash.tags,
        "@source" => Rackstash.source
      )
      event.to_json
    end
  end
end