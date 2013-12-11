require 'test_helper'
require 'rackstash'

if Rackstash.framework == "rails3"
  require 'rackstash/log_subscriber'
  require 'active_support/notifications'

  describe Rackstash::LogSubscriber do
    let(:log_output){ StringIO.new }
    let(:base_logger){ Logger.new(log_output) }
    let(:logger){ Rackstash::BufferedLogger.new(base_logger) }

    let(:flush_and_pop_buffer){ logger.flush_and_pop_buffer }
    let(:json) do
      flush_and_pop_buffer

      JSON.parse(log_output.string.lines.to_a.last)
    end

    let(:subscriber){ Rackstash::LogSubscriber.new }
    let(:event) do
      now = Time.now
      duration = 123 # milliseconds
      ActiveSupport::Notifications::Event.new(
        "process_action.action_controller", now, now + (duration.to_f / 1000), 2, {
          :status => 200, :format => "application/json", :method => "GET", :path => "/home?foo=bar",
          :params => {
            "controller" => "home", "action" => "index", "foo" => "bar"
          }, :db_runtime => 0.02, :view_runtime => 0.01
        }
      )
    end

    let(:redirect) do
      ActiveSupport::Notifications::Event.new(
        'redirect_to.action_controller', Time.now, Time.now, 1, :location => 'http://example.com', :status => 302
      )
    end

    before do
      @original_rails_logger = Rails.logger
      Rails.logger = logger
      logger.push_buffer
    end
    after do
      flush_and_pop_buffer
      Rails.logger = @original_rails_logger
    end

    describe "#redirect_to" do
      it "should store the location in a thread local variable" do
        subscriber.redirect_to(redirect)
        Thread.current[:rackstash_location].must_equal "http://example.com"
      end
    end

    describe "#process_action" do
      it "includes the controller and action" do
        subscriber.process_action(event)
        json["@fields"]["controller"].must_equal "home"
        json["@fields"]["action"].must_equal "index"
      end

      it "includes the duration" do
        subscriber.process_action(event)
        json["@fields"]["duration"].must_be_within_epsilon 123
      end

      it "should include the view rendering time" do
        subscriber.process_action(event)
        json["@fields"]["view"].must_be_within_epsilon 0.01
      end

      it "should include the database rendering time" do
        subscriber.process_action(event)
        json["@fields"]["db"].must_be_within_epsilon 0.02
      end

      it "should add a 500 status when an exception occurred" do
        event.payload[:status] = nil
        event.payload[:exception] = ['AbstractController::ActionNotFound', 'Route not found']
        subscriber.process_action(event)

        json["@fields"]["error"].must_equal "AbstractController::ActionNotFound"
        json["@fields"]["error_message"].must_equal "Route not found"
      end
    end
  end
end
