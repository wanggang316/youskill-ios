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

def rotate(device, orientation)
  result = run("sim-use", "ios", "rotate", orientation, "--device", device)
  raise "Display did not rotate: #{result}" unless result.include?("Rotated to #{orientation}")
end

def restore_display_session(device)
  # XCTest can leave Duo with an active but blank app window. Keep the device booted.
  run("xcrun", "simctl", "spawn", device, "launchctl", "stop", "com.apple.SpringBoard")
  run("xcrun", "simctl", "spawn", device, "launchctl", "stop", "com.apple.CoreSimulator.bridge")
  run("sim-use", "daemon", "stop", "--udid", device)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 60
  loop do
    stdout, = Open3.capture3("sim-use", "describe-ui", "--device", device, "--json", "--no-raw")
    data = JSON.parse(stdout)
    return if data["ok"] && data.dig("data", "screen", "width").to_f > 0
    raise "Duo display session did not recover: #{data}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
    unless data["ok"]
      run("xcrun", "simctl", "spawn", device, "launchctl", "stop", "com.apple.CoreSimulator.bridge")
      run("sim-use", "daemon", "stop", "--udid", device)
    end
    sleep 1
  end
end

def assert_visible(device, output, name, label)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30
  loop do
    data = JSON.parse(run("sim-use", "describe-ui", "--device", device, "--json", "--no-raw"))
    raise "Accessibility query failed: #{data}" unless data.fetch("ok")
    File.write(File.join(output, "duo-#{name}.json"), JSON.pretty_generate(data))
    entries = data.fetch("data").fetch("entries")
    return if entries.any? { |entry| entry["label"] == label && entry.fetch("frame", {}).fetch("width", 0) > 0 && entry.fetch("frame", {}).fetch("height", 0) > 0 }
    raise "#{label} is not visible after #{name}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
    sleep 1
  end
end

def assert_catalog_columns(device, output, name, expanded:)
  data = JSON.parse(run("sim-use", "describe-ui", "--device", device, "--json", "--no-raw"))
  raise "Accessibility query failed: #{data}" unless data.fetch("ok")
  File.write(File.join(output, "duo-#{name}.json"), JSON.pretty_generate(data))
  entries = data.fetch("data").fetch("entries")
  catalog = entries.find { |entry| entry["uniqueId"] == "catalog.category.1" }
  result = entries.find { |entry| entry["uniqueId"] == "skill.card.1" }
  raise "Selected scope results are missing after #{name}" unless result
  if expanded
    raise "Catalog is missing after #{name}" unless catalog
    left, right = catalog.fetch("frame"), result.fetch("frame")
    raise "Catalog and results must occupy separate columns" unless left.fetch("x") + left.fetch("width") <= right.fetch("x")
  else
    raise "Compact results must not show the catalog" if catalog
  end
end

begin
  restore_display_session(device)
  run("sim-use", "ios", "fold", "closed", "--device", device, "--json")
  rotate(device, "portrait")
  run("xcrun", "simctl", "launch", "--terminate-running-process", device, "com.gumpw.youskill",
      "--ui-testing", "--ui-fixtures", "-AppleLanguages", "(en)", "-AppleLocale", "en_US")
  tap(device, "catalog.category.1")
  assert_visible(device, output, "selected-category", "Development")
  assert_catalog_columns(device, output, "compact-category", expanded: false)
  run("sim-use", "ios", "fold", "open", "--device", device, "--json")
  run("sim-use", "ios", "rotate", "landscape-right", "--device", device)
  assert_visible(device, output, "expanded-category", "Development")
  assert_catalog_columns(device, output, "expanded-columns", expanded: true)
  run("sim-use", "ios", "fold", "closed", "--device", device, "--json")
  assert_visible(device, output, "collapsed-category", "Development")
  assert_catalog_columns(device, output, "collapsed-columns", expanded: false)
  tap(device, "skill.card.1")
  tap(device, "detail.files")
  tap(device, "detail.file.example.swift")
  assert_visible(device, output, "initial", "example.swift")
  rotate(device, "landscape-left")
  assert_visible(device, output, "cover-landscape", "example.swift")
  rotate(device, "portrait")

  %w[open closed open].each_with_index do |posture, index|
    result = run("sim-use", "ios", "fold", posture, "--device", device, "--json")
    File.write(File.join(output, "duo-posture-#{index}.json"), result)
    assert_visible(device, output, "#{index}-#{posture}", "example.swift")
    tap(device, "detail.files")
    assert_visible(device, output, "#{index}-drawer", "archive.zip")
    # The reader identifier can mask the drawer close identifier in the AX tree.
    run("sim-use", "tap", "--device", device, "--label", "Done", "--element-type", "Button", "--wait-timeout", "30")
  end
  rotate(device, "landscape-left")
  assert_visible(device, output, "landscape", "example.swift")
  tap(device, "BackButton")
  tap(device, "skill.card.1")
  assert_visible(device, output, "back-results-reopen", "SKILL.md")
  run("sim-use", "ios", "fold", "closed", "--device", device, "--json")
  assert_visible(device, output, "compact-reader", "SKILL.md")
  tap(device, "BackButton")
  tap(device, "BackButton")
  tap(device, "catalog.all")
  tap(device, "skill.card.1")
  assert_visible(device, output, "reopen", "SKILL.md")
ensure
  run("sim-use", "ios", "rotate", "portrait", "--device", device)
  run("sim-use", "ios", "fold", "closed", "--device", device, "--json")
end
