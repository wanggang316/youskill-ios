#!/usr/bin/env ruby
# Checks the release build number bump and the prepare_release check with
# App Store Connect and the project generator replaced by fakes.
require "fastlane"
require "fileutils"
require "tmpdir"
Fastlane.load_actions

ROOT = File.expand_path("..", __dir__)
# fastlane runs the Fastfile from the fastlane directory.
Dir.chdir(File.join(ROOT, "fastlane"))
flow = Fastlane::FastFile.new(File.expand_path("../fastlane/Fastfile", __dir__))
today = Time.now.strftime("%Y%m%d")
calls = []
remote = nil

def expect_error(message)
  yield
rescue FastlaneCore::Interface::FastlaneError => error
  abort "Unexpected error: #{error.message}" unless error.message.include?(message)
else
  abort "Expected failure: #{message}"
end

def check(label)
  abort "Failed: #{label}" unless yield
  puts "Checked #{label}"
end

%i[success important message].each do |level|
  FastlaneCore::UI.define_singleton_method(level) { |_text| }
end

Dir.mktmpdir("release-build") do |directory|
  key = File.join(directory, "AuthKey.p8")
  File.write(key, "key")
  project = File.join(directory, "project.yml")
  original = File.read(File.join(ROOT, "project.yml"))
  version = YAML.safe_load(original).fetch("settings").fetch("base").fetch("MARKETING_VERSION").to_s
  write_build = ->(build) { File.write(project, original.sub(/CURRENT_PROJECT_VERSION: \S+/, "CURRENT_PROJECT_VERSION: #{build}")) }
  committed = -> { YAML.load_file(project).fetch("settings").fetch("base").fetch("CURRENT_PROJECT_VERSION").to_s }

  flow.define_singleton_method(:project_yml_path) { project }
  flow.define_singleton_method(:connect_api_key) { calls << :api_key; { key_id: "test" } }
  flow.define_singleton_method(:testflight_app_identifier) { "com.example.app" }
  flow.define_singleton_method(:latest_testflight_build_number) do |**options|
    calls << [:latest, options.fetch(:version)]
    remote
  end
  flow.define_singleton_method(:generate_project) { calls << :generate }
  ENV["ASC_KEY_ID"] = "id"
  ENV["ASC_ISSUER_ID"] = "issuer"
  ENV["ASC_KEY_PATH"] = key

  # Bump
  write_build.call("#{today}1")
  remote = "#{today}4"
  check("dry run returns the next build number") { flow.bump_release_build(dry_run: true) == "#{today}5" }
  check("dry run leaves project.yml unchanged") { committed.call == "#{today}1" && !calls.include?(:generate) }
  calls.clear

  check("TestFlight build greater than the committed number sets the next number") { flow.bump_release_build == "#{today}5" }
  check("bump writes project.yml") { committed.call == "#{today}5" }
  check("bump changes only the build number") { File.read(project) == original.sub(/CURRENT_PROJECT_VERSION: \S+/, "CURRENT_PROJECT_VERSION: #{today}5") }
  check("bump asks App Store Connect for the marketing version, then regenerates") do
    calls == [:api_key, [:latest, version], :generate]
  end
  calls.clear

  write_build.call("20200101")
  remote = 0
  check("no App Store Connect build gives the date") { flow.bump_release_build == today }
  write_build.call("#{today}7")
  remote = "#{today}2"
  check("committed number greater than App Store Connect build is the base") { flow.bump_release_build == "#{today}8" }
  calls.clear

  value = ENV.delete("ASC_KEY_ID")
  expect_error("Set ASC_KEY_ID") { flow.bump_release_build }
  ENV["ASC_KEY_ID"] = value
  check("missing API key stops before App Store Connect") { calls.empty? }

  remote = "99999999999999"
  expect_error("No build number for #{today}") { flow.bump_release_build }
  check("impossible number leaves project.yml unchanged") { committed.call == "#{today}8" }

  write_build.call("#{today}8 # pinned")
  remote = 0
  expect_error("exactly one CURRENT_PROJECT_VERSION") { flow.bump_release_build }
  check("unexpected build line leaves project.yml unchanged") { committed.call == "#{today}8" }

  # prepare_release check before tests
  calls.clear
  flow.define_singleton_method(:require_duo_environment!) { calls << :duo }
  flow.define_singleton_method(:sh) do |command, **|
    abort "Unexpected command: #{command}" unless ["git status --porcelain", "git rev-parse HEAD"].include?(command)
    command.start_with?("git status") ? "" : "0" * 40
  end
  stop = Class.new(StandardError)
  flow.define_singleton_method(:verify) { calls << :verify; raise stop }
  prepare = -> { flow.runner.execute(:prepare_release, :ios, {}) }

  write_build.call("#{today}1")
  remote = "#{today}2"
  expect_error("Build #{today}1 is not greater than the latest App Store Connect build #{today}2 of version #{version}. Run ./scripts/bump-build.sh") { prepare.call }
  check("TestFlight build greater than the committed number stops before tests") { !calls.include?(:verify) }
  calls.clear

  remote = "#{today}1"
  expect_error("Run ./scripts/bump-build.sh") { prepare.call }
  check("equal build number stops before tests") { !calls.include?(:verify) }
  calls.clear

  value = ENV.delete("ASC_KEY_PATH")
  expect_error("Set ASC_KEY_PATH before release") { prepare.call }
  ENV["ASC_KEY_PATH"] = value
  check("missing API key stops prepare_release before App Store Connect") { calls == [:duo] }
  calls.clear

  remote = "#{today}"
  begin
    prepare.call
    abort "Expected prepare_release to reach the tests"
  rescue stop
    check("greater committed number reaches the tests") { calls == [:duo, :api_key, [:latest, version], :verify] }
  end
end
puts "Release build number checks passed."
