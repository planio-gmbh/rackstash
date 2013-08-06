require 'rackstash/runner'

require 'minitest/mock'
require 'stringio'
require 'json'

describe Rackstash::Runner do
  def capture_json(*args)
    out, err = capture_io do
      Rackstash::Runner.start(args)
    end
    @json = JSON.parse(out.lines.to_a.last)
  end

  def json
    @json
  end

  def stdin(*data)
    @stdin_original = $stdin
    $stdin = Struct.new(:data) do
      def each_line(&block)
        data.each(&block)
      end
    end.new(data)
  end

  after do
    if @stdin_original
      $stdin = @stdin_original
      @stdin_original = nil
    end
  end

  describe "#capture" do
    it "creates a log entry on STDOUT" do
      stdin "Hello World"
      capture_json "capture"

      json["@message"].must_equal "   [INFO] Hello World"
      json["@source"].must_equal nil
      json["@tags"].must_equal []
      json["@fields"].keys.sort.must_equal %w[log_id pid]
      # Timestamp is less than 2 seconds ago
      timestamp_range = ((Time.now-2)..Time.now)
      method = timestamp_range.respond_to?(:cover?) ? :cover? : :===
      timestamp_range.must_be method, Time.parse(json["@timestamp"])
    end

    it "accepts a custom source" do
      stdin "Hello World"
      capture_json "capture", "--source", "STDIN"

      json["@source"].must_equal "STDIN"
    end

    it "accepts custom fields" do
      stdin "Hello World"
      capture_json "capture", "--fields", "key1:value1", "key2:value2"

      json["@fields"].keys.sort.must_equal %w[key1 key2 log_id pid]
      json["@fields"]["key1"].must_equal "value1"
      json["@fields"]["key2"].must_equal "value2"
    end

    it "can overwrite automatically filled fields" do
      stdin "Hello World"
      capture_json "capture", "--fields", "pid:foo"

      json["@fields"]["pid"].wont_equal Process.pid
      json["@fields"]["pid"].must_equal "foo"
    end

    it "accepts custom tags" do
      stdin "Hello World"
      capture_json "capture", "--tags=foo", "bar", "baz"

      json["@tags"].must_equal %w[foo bar baz]
    end

  end
end
