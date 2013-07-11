require 'rackstash/log_subscriber'

module Rackstash
  module Framework
    module Rails3
      def setup(config={})
        super

        unless Rails.logger.is_a?(Rackstash::BufferedLogger)
          Rackstash.logger = Rackstash::BufferedLogger.new(Rails.logger)
          Rails.logger = Rackstash.logger
          ActiveRecord::Base.logger = Rackstash.logger if defined?(ActiveRecord::Base)
          ActionController::Base.logger = Rackstash.logger if defined?(ActionController::Base)
        end
        # The ANSI color codes in the ActiveRecord logs don't help much in
        # plain JSON
        config.colorize_logging = false

        Rackstash::LogSubscriber.attach_to :action_controller
        ActionController::Base.send :include, Rackstash::Instrumentation
      end
    end
  end
end

require 'rackstash/railtie'
