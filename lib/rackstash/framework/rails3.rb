require 'rackstash/log_subscriber'

module Rackstash
  module Framework
    module Rails3
      def setup(config={})
        super

        unless Rails.logger.is_a?(Rackstash::BufferedLogger)
          # This is required by ActiveRecord >= 4
          if defined?(ActiveRecord::SessionStore::Extension::LoggerSilencer)
            Rackstash::BufferedLogger.send(:include, ActiveRecord::SessionStore::Extension::LoggerSilencer)
          end

          Rackstash.logger = Rackstash::BufferedLogger.new(Rails.logger)
          Rails.logger = Rackstash.logger
          silence_warnings { Object.const_set "RAILS_DEFAULT_LOGGER", Rackstash.logger }

          ActiveRecord::Base.logger = Rackstash.logger if defined?(ActiveRecord::Base)
          ActionController::Base.logger = Rackstash.logger if defined?(ActionController::Base)
          # New in Rails 4
          ActionView::Base.logger = Rackstash.logger if defined?(ActionView::Base) && ActionView::Base.respond_to?(:logger=)
        end
        # The ANSI color codes in the ActiveRecord logs don't help much in
        # plain JSON
        config.colorize_logging = false

        log_subscriber = Rackstash::LogSubscriber.new
        Rackstash::LogSubscriber.attach_to :action_controller, log_subscriber

        # ActionDispatch captures exceptions too early for us to catch
        # Thus, we inject our own exceptions_app to be able to catch the
        # actual backtrace and add it to the fields
        exceptions_app = config.exceptions_app || ActionDispatch::PublicExceptions.new(Rails.public_path)
        config.exceptions_app = lambda do |env|
          log_subscriber._extract_exception_backtrace(env)
          exceptions_app.call(env)
        end

        ActionController::Base.send :include, Rackstash::Instrumentation
      end
    end
  end
end

require 'rackstash/railtie'
