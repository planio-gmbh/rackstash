require 'forwardable'
require 'logger'
require 'securerandom'

require 'rackstash/log_severity'

module Rackstash
  class BufferedLogger
    extend Forwardable
    include Rackstash::LogSeverity

    class SimpleFormatter < ::Logger::Formatter
      def call(severity, timestamp, progname, msg)
        "#{String === msg ? msg : msg.inspect}\n"
      end
    end

    def initialize(logger)
      @logger = logger
      @logger.formatter = SimpleFormatter.new if @logger.respond_to?(:formatter=)
      @buffer = {}

      # Note: Buffered logs need to be explicitly flushed to the underlying
      # logger using +flush_and_pop_buffer+. This will not flush the underlying
      # logger. If this is required, you still need to call
      # +BufferedLogger#logger.flush+
      class << self; def_delegator :@logger, :flush; end if @logger.respond_to?(:flush)
      class << self; def_delegator :@logger, :auto_flushing; end if @logger.respond_to?(:auto_flushing)
      class << self; def_delegator :@logger, :auto_flushing=; end if @logger.respond_to?(:auto_flushing=)
      class << self; def_delegator :@logger, :progname; end if @logger.respond_to?(:progname)
      class << self; def_delegators :@logger, :silencer, :silencer=, :silence; end if @logger.respond_to?(:silencer)
    end

    attr_accessor :formatter
    attr_reader :logger
    def_delegators :@logger, :level, :level=

    def add(severity, message=nil, progname=nil)
      severity ||= UNKNOWN
      return true if level > severity

      progname ||= logger.progname if logger.respond_to?(:progname)
      if message.nil?
        if block_given?
          message = yield
        else
          message = progname
        end
      end

      line = {:severity => severity, :message => message}
      if buffering?
        buffer[:messages] << line
        message
      else
        json = logstash_event([line])
        logger.add(severity, json)
      end
    end

    def <<(message)
      logger << message
    end

    Severities.each do |severity|
      class_eval <<-EOT, __FILE__, __LINE__ + 1
        def #{severity.to_s.downcase}(message = nil, progname = nil, &block)  # def debug(message = nil, progname = nil, &block)
          add(#{severity}, message.to_s, progname, &block)                    #   add(DEBUG, message.to_s, progname, &block)
        end                                                                   # end
                                                                              #
        def #{severity.to_s.downcase}?                                        # def debug?
          #{severity} >= level                                                #   DEBUG >= level
        end                                                                   # end
      EOT
    end

    def fields
      buffer && buffer[:fields]
    end

    def tags
      buffer && buffer[:tags]
    end

    def close
      flush_and_pop_buffer while buffering?
      logger.flush if logger.respond_to?(:flush)
      logger.close if logger.respond_to?(:close)
    end

    def push_buffer
      child_buffer = {
        :messages => [],
        :fields => default_fields,
        :tags => [],
        :do_not_log => false
      }

      self.buffer_stack ||= []
      if parent_buffer = buffer
        parent_buffer[:fields][:child_log_ids] ||= []
        parent_buffer[:fields][:child_log_ids] << child_buffer[:fields][:log_id]
        child_buffer[:fields][:parent_log_id] = parent_buffer[:fields][:log_id]
      end

      self.buffer_stack << child_buffer
      nil
    end

    def flush_and_pop_buffer
      if buffer = self.buffer
        unless buffer[:do_not_log]
          json = logstash_event(buffer[:messages], buffer[:fields], buffer[:tags])
          logger.send(Rackstash.log_level, json)
        end
        logger.flush if logger.respond_to?(:flush)
      end

      pop_buffer
    end

    def buffering?
      !!buffer
    end

    def do_not_log!(yes_or_no=true)
      return false unless buffer
      buffer[:do_not_log] = !!yes_or_no
    end

  protected
    def default_fields
      { :log_id => uuid, :pid => Process.pid }
    end

    def buffer
      buffer_stack && buffer_stack.last
    end

    def buffer_stack
      @buffer[Thread.current.object_id]
    end

    def buffer_stack=(stack)
      @buffer[Thread.current.object_id] = stack
    end

    # This method removes the top-most buffer.
    # It does not flush the buffer in any way. Use +flush_and_pop_buffer+
    # for that.
    def pop_buffer
      poped = nil

      if buffer_stack
        poped = buffer_stack.pop
        # We need to delete the whole array to prevent a memory leak
        # from piling threads
        @buffer.delete(Thread.current.object_id) unless buffer_stack.any?
      end
      poped
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

    def logstash_event(logs=[], fields=default_fields, tags=[])
      message = logs.map do |line|
        # normalize newlines
        msg = line[:message].gsub(/[\n\r]/, "\n")
        # remove any leading newlines and a single trailing newline
        msg = msg.sub(/\A\n+/, '').sub(/\n\z/, '')
        "[#{Severities[line[:severity]]}] ".rjust(10) + msg
      end.join("\n")

      custom_fields = Rackstash.fields
      fields = fields.merge(custom_fields) if custom_fields
      event = LogStash::Event.new(
        "@message" => message,
        "@fields" => fields,
        "@tags" => (Rackstash.tags | tags),
        "@source" => Rackstash.source
      )
      event.to_json
    end
  end
end
