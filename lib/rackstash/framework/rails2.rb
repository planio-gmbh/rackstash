require 'rackstash/rails_ext/initializer'
require 'initializer'
Rails::Initializer.class_eval{ include Rackstash::RailsExt::Initializer }

module Rackstash
  module Framework
    module Rails2
      def setup(config={})
        super

        unless RAILS_DEFAULT_LOGGER.is_a?(Rackstash::BufferedLogger)
          rackstash_logger = Rackstash::BufferedLogger.new(RAILS_DEFAULT_LOGGER)
          silence_warnings { Object.const_set "RAILS_DEFAULT_LOGGER", rackstash_logger }
          Rackstash.logger = rackstash_logger
        end

        if Rails.configuration.frameworks.include?(:action_controller)
          require 'rackstash/rails_ext/action_controller'
          ActionController::Base.class_eval{ include Rackstash::RailsExt::ActionController }

          # Include the logger middleware at the earliest possible moment
          # to add a log scope which captures all log lines of the request
          ActionController::Dispatcher.middleware.insert(0, Rackstash::LogMiddleware)
        end
      end
    end
  end
end

Rails::Configuration.class_eval do
  def rackstash
    @rackstash ||= Rails::OrderedOptions.new
  end
end