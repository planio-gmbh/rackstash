require 'active_support/core_ext/class/attribute'
require 'active_support/log_subscriber'

module Rackstash
  class LogSubscriber < ActiveSupport::LogSubscriber
    def process_action(event)
      payload = event.payload

      data      = extract_request(payload)
      data.merge! extract_exception(payload)
      data.merge! runtimes(event)
      data.merge! location(event)

      Rails.logger.fields.reverse_merge!(data)
      Rails.logger.fields.merge! request_fields(payload)
    end

    def redirect_to(event)
      Thread.current[:rackstash_location] = event.payload[:location]
    end

    protected
    def extract_request(payload)
      {
        :controller => payload[:params]['controller'],
        :action => payload[:params]['action'],
        :format => extract_format(payload)
      }
    end

    def extract_format(payload)
      if ::ActionPack::VERSION::MAJOR == 3 && ::ActionPack::VERSION::MINOR == 0
        payload[:formats].first
      else
        payload[:format]
      end
    end

    def extract_exception(payload)
      if payload[:exception]
        exception, message = payload[:exception]
        ret = {
          :error => exception.to_s,
          :error_message => message
        }
        ret[:error_backtrace] = payload[:exception_backtrace] if payload[:exception_backtrace]
      else
        {}
      end
    end

    def runtimes(event)
      {
        :duration => event.duration,
        :view => event.payload[:view_runtime],
        :db => event.payload[:db_runtime]
      }.inject({}) do |runtimes, (name, runtime)|
        runtimes[name] = runtime.to_f.round(2) if runtime
        runtimes
      end
    end

    def location(event)
      if location = Thread.current[:rackstash_location]
        Thread.current[:rackstash_location] = nil
        { :location => location }
      else
        {}
      end
    end

    def request_fields(payload)
      payload[:rackstash_request_fields] || {}
    end
  end

  module Instrumentation
    extend ActiveSupport::Concern

    def append_info_to_payload(payload)
      super
      payload[:rackstash_request_fields] = Rackstash.request_fields(self)
      payload[:exception_backtrace] = request.env["action_dispatch.exception"].join("\n") if request.env["action_dispatch.exception"]
    end
  end
end
