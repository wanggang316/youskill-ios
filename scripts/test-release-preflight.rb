#!/usr/bin/env ruby
require "fastlane"
require "json"
Fastlane.load_actions

ENV["IOS_TEST_DEVICES"] = "iPhone Duo"
ENV["IOS_SIMULATOR_UDIDS"] = JSON.generate("iPhone Duo" => "selected-device")
flow = Fastlane::FastFile.new(File.expand_path("../fastlane/Fastfile", __dir__))
inventory = JSON.generate("devices" => {
  "com.apple.CoreSimulator.SimRuntime.iOS-27-1" => [
    { "name" => "iPhone Duo", "udid" => "other-device", "state" => "Shutdown" },
    { "name" => "iPhone Duo", "udid" => "selected-device", "state" => "Shutdown" }
  ]
})
boot_result = "Status=4294967295, isTerminal=YES\nFinished"
flow.define_singleton_method(:sh) do |command, **|
  if command.include?("list devices")
    inventory
  elsif command.include?("bootstatus")
    boot_result
  else
    ""
  end
end

def expect_error(message)
  yield
rescue FastlaneCore::Interface::FastlaneError => error
  abort "Unexpected error: #{error.message}" unless error.message.include?(message)
else
  abort "Expected failure: #{message}"
end

device = flow.selected_simulators.fetch(0)
abort "The explicit UDID did not select the intended device." unless device.fetch("udid") == "selected-device"
flow.activate_simulator(device)
boot_result = "Status=3, isTerminal=YES\nData Migration Failed"
expect_error("data migration failed") { flow.activate_simulator(device) }

ENV["IOS_SIMULATOR_UDIDS"] = JSON.generate("iPhone Duo" => "missing-device")
expect_error("Missing simulator") { flow.selected_simulators }
ENV["IOS_SIMULATOR_UDIDS"] = "[]"
expect_error("JSON object") { flow.selected_simulators }
ENV["IOS_SIMULATOR_UDIDS"] = "not-json"
expect_error("JSON object") { flow.selected_simulators }
puts "Release preflight checks passed."
