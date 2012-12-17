require 'rackstash/rails_ext/initializer'
require 'initializer'
Rails::Initializer.class_eval{ include Rackstash::RailsExt::Initializer }

module Rackstash
  module Framework
    module Rails2
      # This method MUST be called after Rails::Initializer#initialize_logger
      # but before Rails::Initializer#initialize_framework_logging
      # The Rackstash::RailsExt::Initializer module takes care of that.
      def setup(config={})
        super

        if config[:zmq] && config[:zmq][:enabled]
          logger = zmq_logger(Rails.configuration.log_level, config[:zmq])
        else
          logger = RAILS_DEFAULT_LOGGER
        end

        unless logger.is_a?(Rackstash::BufferedLogger)
          rackstash_logger = Rackstash::BufferedLogger.new(logger)
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

        if Rails.configuration.frameworks.include?(:active_record)
          # The ANSI color codes in the ActiveRecord logs don't help much in
          # plain JSON
          ActiveRecord::Base.colorize_logging = false
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
