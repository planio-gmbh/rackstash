# THIS IS FOR RAILS 2.x COMPATIBILITY ONLY
#
# This module, when included into Rails::Initializer
# makes sure that our buffered logger gets configured right away.

module Rackstash
  module RailsExt
    module Initializer
      def self.included(base)
        base.class_eval do
          alias_method_chain :initialize_logger, :rackstash
        end
      end

      def initialize_logger_with_rackstash
        initialize_logger_without_rackstash
        Rackstash.setup(configuration.rackstash)
      end
    end
  end
end
