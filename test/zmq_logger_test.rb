require 'test_helper'

require 'rackstash/zmq_logger'

describe Rackstash::ZmqLogger do
  def with_server(&block)
    context = ZMQ::Context.new(1)
    server = context.socket(ZMQ::SUB)
    server.bind("tcp://127.0.0.1:32378")
    server.setsockopt(ZMQ::SUBSCRIBE, "")

    yield server
  ensure
    server.close if server
    context.close if context
  end

  def receive_from(socket)
    timeout = 1 # seconds
    3.times do |tries|
      if ZMQ.select( [socket], nil, nil, timeout )
        return socket.recv
      end
    end
    raise "Timeout: Couldn't read from ZMQ socket"
  end

  before do
    log_level = Rackstash::LogSeverity::DEBUG
    socket_address = "127.0.0.1:32378"
    socket_type = ZMQ::PUB
    socket_options = {}

    @logger = Rackstash::ZmqLogger.new(socket_address, log_level, socket_type, socket_options)
  end

  it "should send logs" do
    with_server do |server|
      @logger.info("Hello world")
      receive_from(server).must_equal "Hello world"
    end
  end
end
