#!/usr/bin/env ruby
# Checks the ios beta lane flow with every network and build step stubbed.
require "fastlane"
require "tmpdir"
Fastlane.load_actions

ROOT = File.expand_path("..", __dir__)
# fastlane runs the Fastfile from the fastlane directory.
Dir.chdir(File.join(ROOT, "fastlane"))
flow = Fastlane::FastFile.new(File.expand_path("../fastlane/Fastfile", __dir__))
head = `git -C #{ROOT} rev-parse HEAD`.strip
# CI checks out one commit, so the previous build uses HEAD itself.
parent = head
today = Time.now.strftime("%Y%m%d")
version = flow.project_version.fetch("MARKETING_VERSION").to_s
distribute = flow.method(:distribute_testflight_build)
previous_notes = flow.method(:previous_testflight_notes)
calls = []
messages = []
status = ""
gate_error = nil
dry_ipa = nil

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
  FastlaneCore::UI.define_singleton_method(level) { |text| messages << text.to_s }
end

Dir.mktmpdir("testflight-lane") do |directory|
  key = File.join(directory, "AuthKey.p8")
  File.write(key, "key")
  ipa = File.join(directory, "YouSkill.ipa")
  ipa_build = nil

  flow.define_singleton_method(:sh) do |command, **|
    case command
    when "git status --porcelain" then status
    when "git rev-parse HEAD" then head
    else abort "Unexpected command: #{command}"
    end
  end
  flow.define_singleton_method(:testflight_gate) do
    calls << :gate
    raise gate_error if gate_error
  end
  flow.define_singleton_method(:connect_api_key) { calls << :api_key; { key_id: "test" } }
  flow.define_singleton_method(:latest_testflight_build_number) do |**options|
    calls << [:latest, options.fetch(:version)]
    "#{today}5"
  end
  flow.define_singleton_method(:testflight_app) { calls << :app; :app }
  flow.define_singleton_method(:previous_testflight_notes) { |_app| [["Source revision: #{parent}\n\n- Earlier"]] }
  flow.define_singleton_method(:build_app) do |**options|
    calls << :archive
    ipa_build = options.fetch(:xcargs)[/CURRENT_PROJECT_VERSION=(\d+)/, 1]
  end
  flow.define_singleton_method(:lane_context) { { Fastlane::Actions::SharedValues::IPA_OUTPUT_PATH => ipa } }
  FastlaneCore::IpaFileAnalyser.define_singleton_method(:fetch_app_version) { |_path| version }
  FastlaneCore::IpaFileAnalyser.define_singleton_method(:fetch_app_build) { |_path| ipa_build }
  flow.define_singleton_method(:testflight_record_path) { |build| File.join(directory, build, "build.json") }
  flow.define_singleton_method(:upload_to_testflight) do |**options|
    calls << [:upload, options.fetch(:ipa), options.fetch(:skip_waiting_for_build_processing)]
  end
  flow.define_singleton_method(:distribute_testflight_build) { |record| calls << [:distribute, record.fetch("build")] }

  ENV["ASC_KEY_ID"] = "id"
  ENV["ASC_ISSUER_ID"] = "issuer"
  ENV["ASC_KEY_PATH"] = key

  status = " M project.yml"
  expect_error("Commit or stash") { flow.run_testflight_build }
  check("dirty tree stops before the gate") { calls.empty? }
  status = ""

  %w[ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH].each do |name|
    value = ENV.delete(name)
    expect_error("Set #{name}") { flow.run_testflight_build }
    ENV[name] = value
  end
  ENV["ASC_KEY_PATH"] = File.join(directory, "missing.p8")
  expect_error("local .p8 file") { flow.run_testflight_build }
  ENV["ASC_KEY_PATH"] = key
  check("missing API key variables stop before the gate") { calls.empty? }

  gate_error = FastlaneCore::Interface::FastlaneBuildFailure.new("Tests failed")
  begin
    flow.run_testflight_build
    abort "Expected the gate failure"
  rescue FastlaneCore::Interface::FastlaneBuildFailure
    check("gate failure stops before the archive") { calls == [:gate] }
  end
  gate_error = nil
  calls.clear

  check("dry run returns nothing") { flow.run_testflight_build(dry_run: true).nil? }
  check("dry run stops before the archive") { calls == [:gate, :api_key, [:latest, version], :app] }
  check("dry run says nothing was uploaded") { messages.any? { |text| text.include?("Nothing was uploaded") } }
  calls.clear

  record = flow.run_testflight_build
  build = "#{today}6"
  check("build number exceeds the latest App Store Connect build") { record.fetch("build") == build && ipa_build == build }
  check("steps run in order") do
    calls == [:gate, :api_key, [:latest, version], :app, :archive, [:upload, ipa, true], [:distribute, build]]
  end
  check("notes give the source revision") { record.fetch("notes").start_with?("Source revision: #{head}\n") }
  check("notes list commits since the previous build") { record.fetch("notes").include?("Changes since #{parent[0, 12]}:") }
  check("record is kept for beta_distribute") { JSON.parse(File.read(File.join(directory, build, "build.json"))) == record }
  check("upload is reported before distribution") { messages.any? { |text| text.start_with?("State: uploaded.") } }
end

# Distribution with App Store Connect replaced by fakes.
Group = Struct.new(:id, :name, :is_internal_group, :has_access_to_all_builds)
Detail = Struct.new(:internal_build_state)
FakeBuild = Struct.new(:id, :processing_state, :build_beta_detail, :groups) do
  def add_beta_groups(beta_groups:)
    groups.concat(beta_groups)
  end
end
FakeApp = Struct.new(:groups, :created) do
  def get_beta_groups(filter:)
    filter.key?(:builds) ? [] : groups.select { |group| group.name == filter.fetch(:name) }
  end

  def create_beta_group(group_name:, is_internal_group:, has_access_to_all_builds:)
    self.created = Group.new("new-group", group_name, is_internal_group, has_access_to_all_builds)
  end
end

flow.define_singleton_method(:distribute_testflight_build, distribute)
record = { "version" => version, "build" => "#{today}1", "notes" => "Source revision: #{head}" }
app = FakeApp.new([], nil)
remote = nil
notes = nil
flow.define_singleton_method(:testflight_app) { app }
flow.define_singleton_method(:testflight_build) { |_app, _version, _build| remote }
flow.define_singleton_method(:set_testflight_notes) { |_build, text| notes = text }
flow.define_singleton_method(:testflight_group_ids) { |_app, build| build.groups.map(&:id) }

remote = FakeBuild.new("build", "PROCESSING", nil, [])
expect_error("ios beta_distribute build:#{today}1` to distribute this build without a second upload") do
  flow.distribute_testflight_build(record, timeout: 0, interval: 0)
end
check("processing timeout leaves the build undistributed") { remote.groups.empty? && notes.nil? }
remote = nil
expect_error("did not finish processing") { flow.distribute_testflight_build(record, timeout: 0, interval: 0) }

remote = FakeBuild.new("build", "INVALID", nil, [])
expect_error("as INVALID") { flow.distribute_testflight_build(record, timeout: 0, interval: 0) }
remote = FakeBuild.new("build", "VALID", Detail.new("MISSING_EXPORT_COMPLIANCE"), [])
expect_error("MISSING_EXPORT_COMPLIANCE") { flow.distribute_testflight_build(record, timeout: 0, interval: 0) }

messages.clear
remote = FakeBuild.new("build", "VALID", Detail.new("READY_FOR_BETA_TESTING"), [])
flow.distribute_testflight_build(record, timeout: 0, interval: 0)
check("missing Internal group is created as an internal group") { app.created == Group.new("new-group", "Internal", true, false) }
check("build is added to the Internal group") { remote.groups == [app.created] }
check("notes are set") { notes == record.fetch("notes") }
check("processed and available are separate states") do
  messages.index { |text| text.start_with?("State: processed.") } < messages.index { |text| text.start_with?("State: available to testers.") }
end

existing = Group.new("internal-group", "Internal", true, false)
app = FakeApp.new([existing], nil)
remote = FakeBuild.new("build", "VALID", Detail.new("IN_BETA_TESTING"), [])
flow.distribute_testflight_build(record, timeout: 0, interval: 0)
check("existing Internal group is reused") { app.created.nil? && remote.groups == [existing] }

automatic = Group.new("automatic-group", "Internal", true, true)
app = FakeApp.new([automatic], nil)
messages.clear
remote = FakeBuild.new("build", "VALID", Detail.new("IN_BETA_TESTING"), [])
flow.distribute_testflight_build(record, timeout: 0, interval: 0)
check("group with access to all builds is not added again") { remote.groups.empty? }
check("group with access to all builds reports availability") { messages.any? { |text| text.start_with?("State: available to testers.") } }

app = FakeApp.new([existing], nil)
remote = FakeBuild.new("build", "VALID", Detail.new("READY_FOR_BETA_TESTING"), [])
remote.define_singleton_method(:add_beta_groups) { |**| raise "Service unavailable" }
expect_error("Service unavailable Run `bundle exec fastlane ios beta_distribute build:#{today}1`") do
  flow.distribute_testflight_build(record, timeout: 0, interval: 0)
end
remote = FakeBuild.new("build", "INVALID", nil, [])
expect_error("as INVALID. Run `bundle exec fastlane ios beta_distribute") { flow.distribute_testflight_build(record, timeout: 0, interval: 0) }
remote = FakeBuild.new("build", "VALID", Detail.new("READY_FOR_BETA_TESTING"), [])

app = FakeApp.new([Group.new("external-group", "Internal", false, false)], nil)
expect_error("is an external group") { flow.distribute_testflight_build(record, timeout: 0, interval: 0) }

app = FakeApp.new([existing], nil)
flow.define_singleton_method(:testflight_group_ids) { |_app, _build| [] }
expect_error("does not list") { flow.distribute_testflight_build(record, timeout: 0, interval: 0) }

# App Store Connect rejects the betaBuildMetrics relationship that get_builds includes by default.
flow.define_singleton_method(:previous_testflight_notes, previous_notes)
builds_request = nil
NotesBuild = Struct.new(:notes) do
  def get_beta_build_localizations
    notes.map { |text| Struct.new(:whats_new).new(text) }
  end
end
Spaceship::ConnectAPI.define_singleton_method(:get_builds) do |**options|
  builds_request = options
  Struct.new(:to_models).new([NotesBuild.new(["Source revision: #{head}"])])
end
check("previous notes are read from recent builds") do
  flow.previous_testflight_notes(Struct.new(:id).new("app")).first == ["Source revision: #{head}"]
end
check("previous notes request does not include betaBuildMetrics") do
  builds_request.key?(:includes) && !builds_request[:includes].to_s.include?("betaBuildMetrics")
end
puts "TestFlight lane checks passed."
