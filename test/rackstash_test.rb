require 'test_helper'
require 'rackstash'

describe Rackstash do
  let(:log_output){ StringIO.new }
  let(:base_logger){ Logger.new(log_output) }
  def json
    JSON.parse(log_output.string.lines.to_a.last)
  end

  subject do
    Rackstash::BufferedLogger.new(base_logger)
  end

  describe "fields" do
    after do
      Rackstash.fields = HashWithIndifferentAccess.new
    end

    it "can be defined as a Hash" do
      Rackstash.fields = {:foo => :bar}
      Rackstash.fields.must_be_instance_of HashWithIndifferentAccess

      subject.info("foo")
      json["@fields"]["foo"].must_equal "bar"
    end

    it "can be defined as a proc" do
      Rackstash.fields = proc do
        {:foo => :baz}
      end

      subject.info("foo")
      json["@fields"]["foo"].must_equal "baz"
    end
  end

  describe "request_fields" do
    after do
      Rackstash.request_fields = HashWithIndifferentAccess.new
    end

    let(:controller){ Class.new(Object).new }

    it "won't be included in unbuffered mode" do
      Rackstash.request_fields = {:foo => :bar}

      subject.info("foo")
      json["@fields"].keys.wont_include "foo"
    end

    it "can be defined as a hash" do
      Rackstash.request_fields = {:foo => :bar}

      Rackstash.request_fields(controller).must_be_instance_of HashWithIndifferentAccess
      Rackstash.request_fields(controller).must_equal({"foo" => :bar})

      # FIXME: fake a real request and ensure that the field gets set in the log output
      # subject.with_buffer do
      #   subject.info("foo")
      # end
      # json["@fields"]["foo"].must_equal "bar"
    end

    it "can be defined as a proc" do
      Rackstash.request_fields = proc do |request|
        {:foo => :bar}
      end

      Rackstash.request_fields(controller).must_be_instance_of HashWithIndifferentAccess
      Rackstash.request_fields(controller).must_equal({"foo" => :bar})

      # TODO: fake a real request and ensure that the field gets set in the log output
      # subject.with_buffer do
      #   subject.info("hello")
      # end
      # json["@fields"]["foo"].must_equal "bar"
    end

  end
end
