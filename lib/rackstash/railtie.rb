require 'rails/railtie'
require 'action_view/log_subscriber'
require 'action_controller/log_subscriber'

module Rackstash
  class Railtie < Rails::Railtie
    config.rackstash = ActiveSupport::OrderedOptions.new

    config.rackstash.enabled = false

    initializer :rackstash do |app|
      if app.config.rackstash.enabled
        Rackstash.setup(app.config)
        app.middleware.insert(0, Rackstash::LogMiddleware)
      end

    end
  end
end
