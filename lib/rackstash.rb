require 'action_pack'

require 'rackstash/log_severity'
require 'rackstash/buffered_logger'
require 'rackstash/log_middleware'
require 'rackstash/log_scope'
require 'rackstash/version'

# MRI 1.8 doesn't set the RUBY_ENGINE constant required by logstash-event
Object.const_set(:RUBY_ENGINE, "ruby") unless Object.const_defined?(:RUBY_ENGINE)
require "logstash-event"

module Rackstash
  extend Rackstash::LogScope

  # The level with which the logs are emitted, by default info
  mattr_accessor :log_level
  self.log_level = :info

  # Custom fields that will be merged with the log object when we
  # capture a request.
  #
  # Currently supported formats are:
  #  - Hash
  #  - Any object that responds to to_proc and returns a hash
  #
  mattr_writer :request_fields
  self.request_fields = nil
  def self.request_fields(controller)
    if @@request_fields.respond_to?(:to_proc)
      controller.instance_eval(&@@request_fields)
    else
      @@request_fields
    end
  end

  # Custom fields that will be merged with every log object, be it a captured
  # request or not.
  #
  # Currently supported formats are:
  #  - Hash
  #  - Any object that responds to to_proc and returns a hash
  #
  mattr_writer :fields
  self.fields = nil
  def self.fields
    if @@fields.respond_to?(:to_proc)
      @@fields.to_proc.call
    else
      @@fields
    end
  end

  # The source attribute in the generated Logstash output
  mattr_accessor :source

  # The logger object that is used by the actual application
  mattr_accessor :logger

  # Additonal tags which are attached to each buffered log event
  mattr_accessor :tags
  self.tags = []

  def self.framework
    @framework ||= begin
      if Object.const_defined?(:ActionPack)
        ActionPack::VERSION::MAJOR >= 3 ? "rails3" : "rails2"
      else
        "rack"
      end
    end
  end

  require "rackstash/framework/base"
  require "rackstash/framework/#{framework}"
  extend Rackstash::Framework::Base
  extend Rackstash::Framework.const_get(framework.capitalize)
end
