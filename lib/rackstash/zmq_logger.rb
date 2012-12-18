require 'zmq'

module Rackstash
  class ZmqLogger
    include Rackstash::LogSeverity

    attr_accessor :level

    # Use either ZMQ::PUB or ZMQ::PUSH as the socket type.
    # The main difference in our domain is the behavoir when reaching the
    # high water mark (if configured). The ZMQ::PUB type silently discards
    # messages while the ZMQ::PUSH type blocks.
    #
    # The remote ZMQ socket must be configured equivalently.
    def initialize(address, level=DEBUG, zmq_socket_type=ZMQ::PUB, zmq_options={})
      @level = level

      @context = ZMQ::Context.new
      @socket = @context.socket(ZMQ::PUSH)
      zmq_options.each do |k,v|
        @socket.setsockopt(k, v)
      end
      @socket.connect("tcp://#{address}")
    end

    def zmq_setsockopt(key, value)
      @socket.setsockopt(k, v)
    end

    def zmq_getsockopt(key, value)
      @socket.setsockopt(k, v)
    end

    def add(severity, message = nil, progname = nil, &block)
      return if level > severity
      message = (message || (block && block.call) || progname).to_s

      @socket.send(message, ZMQ::NOBLOCK)
    end

    Severities.each do |severity|
      class_eval <<-EOT, __FILE__, __LINE__ + 1
        def #{severity.to_s.downcase}(message = nil, progname = nil, &block)  # def debug(message = nil, progname = nil, &block)
          add(#{severity}, message, progname, &block)                         #   add(DEBUG, message, progname, &block)
        end                                                                   # end
                                                                              #
        def #{severity.to_s.downcase}?                                        # def debug?
          #{severity} >= level                                                #   DEBUG >= level
        end                                                                   # end
      EOT
    end

    def auto_flushing
      1
    end

    def flush
      # We flush automatically after each #add.
      # We are non-blocking anyway \o/
    end

    def close
      @context.close
      @socket.close
    end

    ##
    # :singleton-method:
    # Set to false to disable the silencer
    cattr_accessor :silencer
    self.silencer = true

    # Silences the logger for the duration of the block.
    def silence(temporary_level = ERROR)
      if silencer
        begin
          old_logger_level, self.level = level, temporary_level
          yield self
        ensure
          self.level = old_logger_level
        end
      else
        yield self
      end
    end
  end
end
