require 'test_helper'
require 'rackstash/buffered_logger'

require 'stringio'
require 'json'

describe Rackstash::BufferedLogger do
  let(:log_output){ StringIO.new }
  let(:base_logger){ Logger.new(log_output) }

  def log_line
    log_output.string.lines.to_a.last
  end
  def json
    JSON.parse(log_line)
  end

  subject do
    Rackstash::BufferedLogger.new(base_logger)
  end

  it "must be properly initialized" do
    subject.logger.formatter.must_be_instance_of Rackstash::BufferedLogger::SimpleFormatter
    subject.buffering?.must_equal false
    subject.fields.must_equal nil
    subject.tags.must_equal nil
    subject.source.must_equal nil
  end

  describe "when passing a logger" do
    it "delegates only defined methods" do
      # sanity
      base_logger.wont_respond_to :flush
      base_logger.wont_respond_to :auto_flushing

      base_logger.instance_eval{ def flush; end }

      base_logger.must_respond_to :flush
      base_logger.wont_respond_to :auto_flushing
      subject.must_respond_to :flush
      subject.wont_respond_to :auto_flushing
    end

    it "delegates later methods too" do
      base_logger.wont_respond_to :auto_flushing # sanity
      base_logger.instance_eval{ def auto_flushing; end }

      base_logger.must_respond_to :auto_flushing
      subject.must_respond_to :auto_flushing
    end
  end

  describe "when using the Logger API" do
    it "forwards base methods to the underlying logger" do
      subject.logger.must_be_same_as base_logger

      subject.level.must_equal base_logger.level
      subject.progname.must_be_same_as base_logger.progname
    end
  end

  describe "when logging unbuffered" do
    it "supports adding log messages" do
      subject.add nil, "log_empty"
      json["@message"].must_equal "[UNKNOWN] log_empty"

      %w[debug info warn error fatal unknown].each do |severity|
        subject.send severity, "log_#{severity}"

        tag = "[#{severity.upcase}] ".rjust(10)
        json["@message"].must_equal "#{tag}log_#{severity}"
      end
    end

    it "supports the << method" do
      subject << "Hello World"
      log_output.string.must_equal "Hello World"
    end

    it "ignores the instruction to not log a message" do
      subject.do_not_log!.must_equal false
      subject.info "Hello World"
      json["@message"].must_equal "   [INFO] Hello World"
    end

    it "includes the default fields" do
      subject.info "Foo Bar Baz"

      json = self.json
      json.keys.sort.must_equal %w[@fields @message @source @tags @timestamp]
      json["@fields"].keys.sort.must_equal %w[log_id pid]

      json["@fields"]["pid"].must_equal Process.pid
      json["@fields"]["log_id"].must_match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/)
      json["@message"].must_equal "   [INFO] Foo Bar Baz"
      json["@source"].must_be_nil
      json["@tags"].must_equal []
      # Timestamp is less than 2 seconds ago
      timestamp_range = ((Time.now-2)..Time.now)
      method = timestamp_range.respond_to?(:cover?) ? :cover? : :===
      timestamp_range.must_be method, Time.parse(json["@timestamp"])
    end

    it "allows to log nil" do
      subject.info nil
      json["@message"].must_equal "   [INFO] "
    end

    it "allows to log numerics" do
      subject.info 12.123
      json["@message"].must_equal "   [INFO] 12.123"
    end

    it "allows to set a source" do
      subject.source = "BufferedLoggerTest"
      subject.info nil
      json["@source"].must_equal "BufferedLoggerTest"
    end
  end

  describe "when using a buffer" do
    it "should buffer logs" do
      subject.with_buffer do
        subject.info("Hello")
        log_output.string.must_be_empty
        subject.info("World")
      end

      json["@message"].must_equal "   [INFO] Hello\n   [INFO] World"
    end

    it "can set additional tags" do
      subject.with_buffer do
        subject.tags << :foo
        subject.info("Hello")
      end

      json["@tags"].must_equal ["foo"]
      json["@message"].must_equal "   [INFO] Hello"
    end

    it "can set additional tags for the duration of a block" do
      subject.tagged("foo", "bar") { subject.info "Testing" }
      json["@tags"].must_equal ["foo", "bar"]

      subject.info "Testing"
      json["@tags"].must_equal []
    end

    it "can set additional fields" do
      subject.with_buffer do
        subject.fields[:foo] = :bar
        subject.info("Hello")
      end

      json["@fields"]["foo"].must_equal "bar"
      json["@message"].must_equal "   [INFO] Hello"
    end

    it "can overwrite automatically filled fields" do
      subject.with_buffer do
        subject.fields[:pid] = "foobarbaz"
        subject.info("Hello")
      end

      json["@fields"]["pid"].must_equal "foobarbaz"
      json["@message"].must_equal "   [INFO] Hello"
    end

    it "captures exceptions" do
      exception = Class.new(StandardError) do
        def self.name
          "SomethingWrongError"
        end
      end

      proc do
        subject.with_buffer do
          raise exception, "Something is wrong"
        end
      end.must_raise(exception)

      json["@message"].must_equal ""
      json["@fields"]["error"].must_equal "SomethingWrongError"
      json["@fields"]["error_message"].must_equal "Something is wrong"
      json["@fields"]["error_backtrace"].must_match(/\A#{__FILE__}:\d+/)
      json["@fields"]["error_backtrace"].must_match(/^#{File.expand_path("../../lib/rackstash/buffered_logger.rb", __FILE__)}:\d+:in `with_buffer'$/)
    end

    it "doesn't log anything when using do_not_log!" do
      subject.with_buffer do
        subject.do_not_log!.must_equal true
        subject.info "Hello World"
      end

      log_line.must_be :nil?
    end
  end

  describe "message truncation" do
    before do
      @old_max_message_bytesize = Rackstash.max_message_bytesize
    end

    after do
      Rackstash.max_message_bytesize = @old_max_message_bytesize
    end

    it "does not truncate when the message is under the limit" do
      Rackstash.max_message_bytesize = 1_000

      subject.with_buffer do
        subject.info("Hello")
        subject.info("World")
      end

      json["@message"].must_equal "   [INFO] Hello\n   [INFO] World"
      json["@message"].wont_include "... (truncated) ..."
    end

    it "truncates the message when it exceeds the limit" do
      Rackstash.max_message_bytesize = 200

      subject.with_buffer do
        20.times { |i| subject.info("Log line number #{i}: #{'x' * 40}") }
      end

      message = json["@message"]
      message.bytesize.must_be :<=, 200
      message.must_include "... (truncated) ..."
      message.must_match(/Log line number 0/)
      message.must_match(/Log line number 19/)
    end

    it "does not truncate when limit is nil" do
      Rackstash.max_message_bytesize = nil

      subject.with_buffer do
        20.times { |i| subject.info("Log line number #{i}: #{'x' * 40}") }
      end

      json["@message"].wont_include "... (truncated) ..."
    end

    it "does not truncate when limit is 0" do
      Rackstash.max_message_bytesize = 0

      subject.with_buffer do
        20.times { |i| subject.info("Log line number #{i}: #{'x' * 40}") }
      end

      json["@message"].wont_include "... (truncated) ..."
    end

    it "does not truncate when the message bytesize equals the limit exactly" do
      Rackstash.max_message_bytesize = 1_000

      subject.with_buffer do
        subject.info("Hello")
      end

      # Get the actual bytesize and set the limit to match exactly
      message = json["@message"]
      Rackstash.max_message_bytesize = message.bytesize

      subject.with_buffer do
        subject.info("Hello")
      end

      json["@message"].must_equal message
      json["@message"].wont_include "... (truncated) ..."
    end

    it "handles multi-byte UTF-8 characters without splitting them" do
      Rackstash.max_message_bytesize = 200

      subject.with_buffer do
        10.times { |i| subject.info("Line #{i}: #{'日本語テスト' * 5}") }
      end

      message = json["@message"]
      message.must_include "... (truncated) ..."
      message.bytesize.must_be :<=, 200
      message.valid_encoding?.must_equal true
    end

    it "truncates a single long line using byte-level truncation" do
      Rackstash.max_message_bytesize = 100

      subject.with_buffer do
        subject.info("x" * 500)
      end

      message = json["@message"]
      message.must_include "... (truncated) ..."
      message.bytesize.must_be :<=, 100
      message.must_match(/x{5,}/)
      parts = message.split("... (truncated) ...")
      parts[0].strip.must_match(/x+\z/)
      parts[1].strip.must_match(/x+\z/)
    end

    it "preserves content from both the head and tail" do
      Rackstash.max_message_bytesize = 200

      subject.with_buffer do
        20.times { |i| subject.info("Line #{i}: #{'a' * 30}") }
      end

      message = json["@message"]
      message.must_include "... (truncated) ..."
      message.bytesize.must_be :<=, 200
      message.must_match(/Line 0/)
      message.must_match(/Line 19/)
    end

    it "handles a limit smaller than the truncation marker" do
      Rackstash.max_message_bytesize = 10

      subject.with_buffer do
        subject.info("x" * 500)
      end

      message = json["@message"]
      message.bytesize.must_be :<=, 10
      message.bytesize.must_be :>, 0
      message.wont_include "... (truncated) ..."
    end

    it "handles a limit at the marker boundary" do
      marker_size = Rackstash::BufferedLogger::TRUNCATION_MARKER.bytesize

      Rackstash.max_message_bytesize = marker_size
      subject.with_buffer do
        subject.info("x" * 500)
      end
      json["@message"].bytesize.must_be :<=, marker_size
      json["@message"].wont_include "... (truncated) ..."

      Rackstash.max_message_bytesize = marker_size + 1
      subject.with_buffer do
        subject.info("x" * 500)
      end
      json["@message"].bytesize.must_be :<=, marker_size + 1
      json["@message"].must_include "... (truncated) ..."
    end

    it "stays within the byte limit for various sizes" do
      [50, 77, 100, 150].each do |limit|
        Rackstash.max_message_bytesize = limit

        subject.with_buffer do
          6.times { |i| subject.info("Line #{i}: #{'a' * 30}") }
        end

        message = json["@message"]
        message.must_include "... (truncated) ..."
        message.bytesize.must_be :<=, limit
      end
    end

    it "handles 4-byte UTF-8 characters (emoji) without splitting them" do
      Rackstash.max_message_bytesize = 200

      subject.with_buffer do
        10.times { |i| subject.info("Line #{i}: #{"🎉🔥💯🚀" * 3}") }
      end

      message = json["@message"]
      message.must_include "... (truncated) ..."
      message.bytesize.must_be :<=, 200
      message.valid_encoding?.must_equal true
    end

    it "returns an empty message for an empty log buffer" do
      Rackstash.max_message_bytesize = 200

      subject.with_buffer do
      end

      json["@message"].must_equal ""
      json["@message"].wont_include "... (truncated) ..."
    end

    it "handles mixed severity levels under truncation" do
      Rackstash.max_message_bytesize = 200

      subject.with_buffer do
        subject.debug("debug message: #{'d' * 40}")
        subject.info("info message: #{'i' * 40}")
        subject.warn("warn message: #{'w' * 40}")
        subject.error("error message: #{'e' * 40}")
        subject.fatal("fatal message: #{'f' * 40}")
      end

      message = json["@message"]
      message.must_include "... (truncated) ..."
      message.bytesize.must_be :<=, 200
      message.valid_encoding?.must_equal true
    end
  end
end
