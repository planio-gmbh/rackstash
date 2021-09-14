# THIS IS FOR RAILS 2.x COMPATIBILITY ONLY
#
# This module, when included into ActionController::Base
# makes sure that no superfluous log entries are generated during request
# handling. Instead, only the configured Lograge output is generated

module Rackstash
  module RailsExt
    module ActionController
      def self.included(base)
        base.class_eval do
          # In Rails 2, the ActionController::Benchmark module we are actually
          # patching is included before the ActionController::Rescue module.
          # As we need to preserve the alias chain, we completely replace the call
          # chain. An unmodified ActionController thus uses the following call
          # chain for perform_action:
          #
          # perform_action_with_flash
          # perform_action_without_flash     == perform_action_with_rescue
          # perform_action_without_rescue    == perform_action_with_benchmark
          # perform_action_without_benchmark == perform_action_with_filters
          # perform_action_with_filters      == AC::Base#perform_action
          #
          # We replace the perform_action_without_rescue method with our own
          # to keep up the call chain.

          alias_method :perform_action_without_rescue, :perform_action_with_rackstash
        end
      end

      private
      def perform_action_with_rackstash
        if logger
          rackstash_fields = {
            :controller => params["controller"],
            :action => params["action"],
            :format => params["format"]
          }

          ms = [Benchmark.ms { perform_action_without_benchmark }, 0.01].max
          logging_view          = defined?(@view_runtime)
          logging_active_record = Object.const_defined?("ActiveRecord") && ActiveRecord::Base.connected?

          log_message  = 'Completed in %.0fms' % ms

          if logging_view || logging_active_record
            log_message << " ("
            if logging_view
              log_message << view_runtime
              rackstash_fields[:view] = (@view_runtime * 100).round / 100.0
            end

            if logging_active_record
              db_runtime = active_record_runtime_for_rackstash

              log_message << ", " if logging_view
              log_message << ("DB: %.0f" % db_runtime) + ")"
              rackstash_fields[:db] = (db_runtime * 100).round / 100.0
            else
              ")"
            end
          end
          log_message << " | #{response.status}"
          log_message << " [#{complete_request_uri rescue "unknown"}]"

          logger.info(log_message)
          response.headers["X-Runtime"] = "%.0f" % ms

          rackstash_fields[:duration] = (ms * 100).round / 100.0
          rackstash_fields[:location] = response.location if response.location
        else
          perform_action_without_benchmark
        end
      rescue Exception => exception
        rackstash_fields ||= {}
        rackstash_fields[:error] = exception.class.name
        rackstash_fields[:error_message] = exception.message
        rackstash_fields[:error_backtrace] = exception.backtrace.join("\n") if exception.backtrace
        raise
      ensure
        if logger && logger.respond_to?(:fields) && logger.fields
          rackstash_fields ||= {}
          logger.fields.reverse_merge!(rackstash_fields)

          request_fields = Rackstash.request_fields(self)
          logger.fields.merge!(request_fields) if request_fields

          request_tags = Rackstash.request_tags(self)
          logger.tags.push *request_tags
        end
      end

      # Basically the same as ActionController::Benchmarking#active_record_runtime
      # but we return a float instead of a pre-formatted string.
      private
      def active_record_runtime_for_rackstash
        db_runtime = ActiveRecord::Base.connection.reset_runtime
        db_runtime += @db_rt_before_render if @db_rt_before_render
        db_runtime += @db_rt_after_render if @db_rt_after_render
        db_runtime
      end
    end
  end
end
