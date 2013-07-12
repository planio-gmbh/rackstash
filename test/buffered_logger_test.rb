require 'test_helper'
require 'rackstash'

describe Rackstash::BufferedLogger do
  let(:log_output){ StringIO.new }
  let(:base_logger){ Logger.new(log_output) }

  subject do
    Rackstash::BufferedLogger.new(base_logger)
  end

  it "must be properly initialized" do
    subject.logger.formatter.must_be_instance_of Rackstash::BufferedLogger::SimpleFormatter
    subject.buffering?.must_equal false
    subject.fields.must_equal nil
    subject.tags.must_equal nil
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
      log_output.string.must_include '"@message":"[UNKNOWN] log_empty"'

      %w[debug info warn error fatal unknown].each do |severity|
        subject.send severity, "log_#{severity}"

        tag = "[#{severity.upcase}] ".rjust(10)
        log_output.string.must_include %Q{"@message":"#{tag}log_#{severity}"}
      end
    end

    it "supports the << method" do
      subject << "Hello World"
      log_output.string.must_equal "Hello World"
    end

    it "ignores the instruction to not log a message" do
      subject.do_not_log!.must_equal false
      subject.info "Hello World"
      log_output.string.must_include "Hello World"
    end

    it "includes the default fields" do
      subject.info "Foo Bar Baz"

      json = JSON.parse(log_output.string)
      json.keys.sort.must_equal %w[@fields @message @source @tags @timestamp]
      json["@fields"].keys.sort.must_equal %w[log_id pid]

      json["@fields"]["pid"].must_equal Process.pid
      json["@fields"]["log_id"].must_match /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/
      json["@message"].must_equal "   [INFO] Foo Bar Baz"
      json["@source"].must_be_nil
      json["@tags"].must_equal []
      # Timestamp is less than 2 seconds ago
      ((Time.now-2)..Time.now).must_be :cover?, Time.parse(json["@timestamp"])
    end
  end

  describe "when using a buffer" do
    before{ subject.push_buffer }

    it "should buffer logs" do
      subject.info("Hello")
      log_output.string.must_be_empty

      subject.info("World")
      subject.flush_and_pop_buffer

      log_output.string.must_include '"@message":"   [INFO] Hello\n   [INFO] World"'
    end
  end
end
