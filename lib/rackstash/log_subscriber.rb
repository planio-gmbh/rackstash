require 'active_support/core_ext/class/attribute'
require 'active_support/log_subscriber'

module Rackstash
  class LogSubscriber < ActiveSupport::LogSubscriber
    def process_action(event)
      return unless Rails.logger.respond_to?(:fields) && Rails.logger.fields
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

    def _extract_exception_backtrace(env)
      return unless env['action_dispatch.exception']

      exception_wrapper = ActionDispatch::ExceptionWrapper.new(env, env['action_dispatch.exception'])
      data = {
        :error_backtrace => exception_wrapper.full_trace.join("\n")
      }
      Rails.logger.fields.reverse_merge!(data)
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
        {
          :error => exception.to_s,
          :error_message => message
        }
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
        runtimes[name] = round(runtime, 2) if runtime
        runtimes
      end
    end

    if 0.0.method(:round).arity == 0
      def round(float, ndigits=0)
        power = (10**ndigits).to_f
        (float * power).round / power
      end
    else
      def round(float, ndigits=0)
        float.to_f.round(ndigits)
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
    end
  end
end
