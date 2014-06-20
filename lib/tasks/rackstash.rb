desc "Execute a sub-task in a rackstash log scope"
task :with_rackstash, [:task] do |t, args|
  Rake::Task[:environment].invoke if Rake::Task[:environment]

  Rackstash.tags |= ["rake", "rake::#{args[:task]}"]
  Rackstash.with_log_buffer do
    Rake::Task[args[:task]].invoke
  end
end
