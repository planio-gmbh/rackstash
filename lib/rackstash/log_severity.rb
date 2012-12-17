module Rackstash
  module LogSeverity
    Severities = [:DEBUG, :INFO, :WARN, :ERROR, :FATAL, :UNKNOWN]

    Severities.each_with_index do |s,i|
      const_set(s, i)
    end
  end
end
