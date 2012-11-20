module Rackstash
  module Framework
    module Base
      def setup(config={})
        Rackstash.request_fields = config[:request_fields]
        Rackstash.source = config[:source]
        Rackstash.log_level = config[:log_level] || :info
        Rackstash.tags = config[:tags] || []
      end
    end
  end
end