require 'test_helper'
require 'rackstash'

require 'action_controller' if Rackstash.framework == "rails3"

if Rackstash.framework == "rails3" && defined?(ActionController::API)
  require 'active_support/notifications'

  describe "Rackstash.setup with Rails" do
    let(:config) do
      config = ActiveSupport::OrderedOptions.new
      config.rackstash = ActiveSupport::OrderedOptions.new
      config.rackstash.request_fields = proc { { :host => request.host } }
      config
    end

    def controller_class(superclass)
      Class.new(superclass) do
        def self.name
          "TestController"
        end

        def index
          head :ok
        end
      end
    end

    def payload_of_request_to(controller)
      payload = nil
      callback = lambda { |*args| payload = args.last }

      ActiveSupport::Notifications.subscribed(callback, "process_action.action_controller") do
        controller.action(:index).call(Rack::MockRequest.env_for("http://api.example.com/"))
      end
      payload
    end

    before do
      @original_rails_logger = Rails.logger
      Rails.logger = Logger.new(StringIO.new)
      Rackstash.setup(config)
    end
    after do
      Rails.logger = @original_rails_logger
    end

    it "adds the request fields to the payload of API controllers" do
      payload = payload_of_request_to(controller_class(ActionController::API))

      _(payload[:rackstash_request_fields]).must_equal("host" => "api.example.com")
    end

    it "adds the request fields to the payload of Base controllers" do
      payload = payload_of_request_to(controller_class(ActionController::Base))

      _(payload[:rackstash_request_fields]).must_equal("host" => "api.example.com")
    end
  end
end
