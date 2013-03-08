desc "Execute a sub-task in a rackstash log scope"
task :with_rackstash, [:task] do |t, args|
  Rake::Task[:environment].invoke if Rake::Task[:environment]

  Rackstash.with_log_buffer do
    Rackstash.logger.tags << "rake"
    Rackstash.logger.tags << "rake::#{args[:task]}"

    Rake::Task[args[:task]].invoke
  end
end
