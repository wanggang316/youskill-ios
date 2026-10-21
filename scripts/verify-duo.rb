#!/usr/bin/env ruby
# Verify display changes without relaunching the app or resetting navigation.
require "json"
require "open3"
require "fileutils"

device, output = ARGV
abort "Usage: ruby scripts/verify-duo.rb UDID OUTPUT_DIRECTORY" unless device && output
FileUtils.mkdir_p(output)

def run(*command)
  stdout, stderr, status = Open3.capture3(*command)
  raise "#{command.first} failed: #{stderr}\n#{stdout}" unless status.success?
  stdout
end

def tap(device, identifier)
  run("sim-use", "tap", "--device", device, "--id", identifier, "--wait-timeout", "30")
end

def assert_visible(device, output, name, label)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30
  loop do
    data = JSON.parse(run("sim-use", "describe-ui", "--device", device, "--json", "--no-raw"))
    raise "Accessibility query failed: #{data}" unless data.fetch("ok")
    File.write(File.join(output, "duo-#{name}.json"), JSON.pretty_generate(data))
    entries = data.fetch("data").fetch("entries")
    return if entries.any? { |entry| entry["label"] == label && entry.fetch("w", 0) > 0 && entry.fetch("h", 0) > 0 }
    raise "#{label} is not visible after #{name}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
    sleep 1
  end
end

begin
  run("sim-use", "ios", "fold", "closed", "--device", device, "--json")
  run("xcrun", "simctl", "launch", "--terminate-running-process", device, "com.gumpw.youskill",
      "--ui-testing", "--ui-fixtures", "-AppleLanguages", "(en)", "-AppleLocale", "en_US")
  tap(device, "catalog.all")
  tap(device, "skill.card.1")
  tap(device, "detail.files")
  tap(device, "detail.file.example.swift")
  assert_visible(device, output, "initial", "example.swift")

  %w[open closed open].each_with_index do |posture, index|
    result = run("sim-use", "ios", "fold", posture, "--device", device, "--json")
    File.write(File.join(output, "duo-posture-#{index}.json"), result)
    assert_visible(device, output, "#{index}-#{posture}", "example.swift")
    tap(device, "detail.files")
    assert_visible(device, output, "#{index}-drawer", "archive.zip")
    tap(device, "detail.files.close")
  end
  run("sim-use", "ios", "rotate", "landscape-left", "--device", device)
  assert_visible(device, output, "landscape", "example.swift")
  tap(device, "BackButton")
  tap(device, "skill.card.1")
  assert_visible(device, output, "back-results-reopen", "SKILL.md")
  tap(device, "BackButton")
  tap(device, "BackButton")
  tap(device, "catalog.all")
  tap(device, "skill.card.1")
  assert_visible(device, output, "reopen", "SKILL.md")
ensure
  run("sim-use", "ios", "rotate", "portrait", "--device", device)
  run("sim-use", "ios", "fold", "closed", "--device", device, "--json")
end
