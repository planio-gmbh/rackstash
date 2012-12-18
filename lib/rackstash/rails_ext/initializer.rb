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
        zmq_config = configuration.rackstash.zmq

        if !Rails.logger && !configuration.logger && zmq_config.enabled
          require 'rackstash/zmq_logger'

          log_level = Rackstash::LogSeverity.const_get(configuration.log_level.to_s.upcase)
          socket_address = zmq_config.address || "127.0.0.1:5555"
          socket_type = ZMQ.const_get((zmq_config.socket_type || "PUB").to_s.upcase)
          socket_options = (zmq_config.socket_options || {}).inject({}) do |opts, (k, v)|
            opts[ZMQ.const_get(k)] = v
            opts
          end

          logger = Rackstash::ZmqLogger.new(socket_address, log_level, socket_type, socket_options)
          silence_warnings { Object.const_set "RAILS_DEFAULT_LOGGER", logger }
        else
          initialize_logger_without_rackstash
        end

        Rackstash.setup(configuration.rackstash)
      end
    end
  end
end
