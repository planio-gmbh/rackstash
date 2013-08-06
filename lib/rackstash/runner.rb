require 'thor'
require 'rackstash/buffered_logger'
require 'stringio'

module Rackstash
  class Runner < Thor
    default_task :capture

    desc "capture", "Capture and buffer STDIN and generate a log entry on STDOUT"
    method_option :tags, :type => :array, :required => false, :desc => "Tags to set on the Log entry"
    method_option :fields, :type => :hash, :required => false, :desc => "Additional fields"
    method_option :source, :type => :string, :required => false, :desc => "The source attribute"
    def capture
      logger.with_buffer do
        $stdin.each_line do |line|
          logger.info(line)
        end
        logger.source = options[:source]

        logger.fields.merge!(options[:fields] || {})
        logger.tags.push *(options[:tags] || [])
      end

      puts output.string
    end

  protected
    def output
      @output ||= StringIO.new
    end

    def logger
      @logger ||= Rackstash::BufferedLogger.new(Logger.new(output))
    end
  end
end
