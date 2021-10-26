require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/version'
if ActiveSupport::VERSION::MAJOR < 3
  Hash.send(:include, ActiveSupport::CoreExtensions::Hash::IndifferentAccess) unless Hash.included_modules.include? ActiveSupport::CoreExtensions::Hash::IndifferentAccess
end

require 'rackstash/buffered_logger'
require 'rackstash/log_middleware'
require 'rackstash/version'

module Rackstash
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
  self.request_fields = HashWithIndifferentAccess.new
  def self.request_fields(controller)
    if !@@request_fields.is_a?(Hash) && @@request_fields.respond_to?(:to_proc)
      ret = controller.instance_eval(&@@request_fields)
    else
      ret = @@request_fields
    end
    HashWithIndifferentAccess.new(ret)
  end

  # Custom fields that will be merged with every log object, be it a captured
  # request or not.
  #
  # Currently supported formats are:
  #  - Hash
  #  - Any object that responds to to_proc and returns a hash
  #
  mattr_writer :fields
  self.fields = HashWithIndifferentAccess.new
  def self.fields
    if !@@fields.is_a?(Hash) and @@fields.respond_to?(:to_proc)
      ret = @@fields.to_proc.call
    else
      ret = @@fields
    end
    HashWithIndifferentAccess.new(ret)
  end

  # The source attribute in the generated Logstash output
  mattr_accessor :source

  # The logger object that is used by the actual application
  mattr_accessor :logger

  # Additonal tags which are attached to each buffered log event
  mattr_reader :tags
  def self.tags=(tags)
    @@tags = tags.map(&:to_s)
  end
  self.tags = []

  def self.with_log_buffer(&block)
    if Rackstash.logger.respond_to?(:with_buffer)
      Rackstash.logger.with_buffer(&block)
    else
      yield
    end
  end

  def self.framework
    @framework ||= begin
      if Object.const_defined?(:Rails)
        Rails::VERSION::MAJOR >= 3 ? "rails3" : "rails2"
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
