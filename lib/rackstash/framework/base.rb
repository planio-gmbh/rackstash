module Rackstash
  module Framework
    module Base
      def setup(config={})
        Rackstash.request_fields = config.rackstash[:request_fields]
        Rackstash.fields = config.rackstash[:fields] || HashWithIndifferentAccess.new
        Rackstash.source = config.rackstash[:source]
        Rackstash.log_level = config.rackstash[:log_level] || :info
        Rackstash.tags = config.rackstash[:tags] || []
      end
    end
  end
end
