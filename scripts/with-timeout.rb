#!/usr/bin/env ruby
require "timeout"

seconds = Float(ARGV.shift || "0")
abort "Usage: ruby scripts/with-timeout.rb SECONDS COMMAND [ARGUMENTS]" unless seconds.positive? && !ARGV.empty?

pid = Process.spawn(*ARGV, pgroup: true)
begin
  _, status = Timeout.timeout(seconds) { Process.wait2(pid) }
  exit(status.exitstatus || 1)
rescue Timeout::Error
  warn "Command timed out after #{seconds} seconds: #{ARGV.first}"
  Process.kill("TERM", -pid)
  begin
    Timeout.timeout(5) { Process.wait(pid) }
  rescue Timeout::Error
    Process.kill("KILL", -pid)
    Process.wait(pid)
  end
  exit 124
end
