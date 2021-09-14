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
  #  - Any object that responds to #call and returns a hash
  #
  mattr_writer :request_fields
  self.request_fields = HashWithIndifferentAccess.new
  def self.request_fields(controller)
    fields = @@request_fields
    fields = fields.call(controller.request) if fields.respond_to?(:call)
    HashWithIndifferentAccess.new(fields)
  end

  # Custom fields that will be merged with every log object, be it a captured
  # request or not.
  #
  # Currently supported formats are:
  #  - Hash
  #  - Any object that responds to #call and returns a hash
  #
  mattr_writer :fields
  self.fields = HashWithIndifferentAccess.new
  def self.fields
    fields = @@fields
    fields = fields.call if fields.respond_to?(:call)
    HashWithIndifferentAccess.new(fields)
  end

  # The source attribute in the generated Logstash output
  mattr_accessor :source

  # The logger object that is used by the actual application
  mattr_accessor :logger

  # Additonal tags which are attached to each buffered log event
  mattr_reader :tags
  def self.tags=(tags)
    @@tags = tags.map(&:to_s).uniq
  end
  self.tags = []

  # Additional tags to be included when processing a request.
  mattr_writer :request_tags
  self.request_tags = []
  def self.request_tags(controller)
    @@request_tags.map do |request_tag|
      if request_tag.respond_to?(:call)
        request_tag.call(controller.request)
      else
        request_tag
      end
    end
  end

  def self.tagged(*tags, &block)
    if block_given?
      original_tags = self.tags
      begin
        with_log_buffer do
          self.tags += tags
          yield
        end
      ensure
        self.tags = original_tags
      end
    else
      self.tags += tags
    end
  end

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
