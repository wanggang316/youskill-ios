#!/usr/bin/env ruby
require 'tmpdir'
require_relative 'testflight-build'

def expect(label, actual, expected)
  abort "#{label}: expected #{expected.inspect}, got #{actual.inspect}" unless actual == expected
  puts "Checked #{label}"
end

def expect_error(label)
  yield
  abort "Expected failure: #{label}"
rescue TestFlightBuild::Error => error
  puts "Rejected #{label}: #{error.message}"
end

next_build = ->(latest) { TestFlightBuild.next_build_number(date: '20261102', latest: latest) }
expect('first build on a new day', next_build.call(['202610221']), '202611021')
expect('first build when only older short numbers exist', next_build.call(%w[20261020 0]), '20261102')
expect('first build with no previous build', next_build.call([nil, 0]), '20261102')
expect('second build on the same day', next_build.call(['20261102']), '202611021')
expect('third build on the same day', next_build.call(['202611021']), '202611022')
expect('tenth build on the same day', next_build.call(['202611029']), '2026110210')
expect('remote build greater than local build', next_build.call(['202610221', '202611023']), '202611024')
expect('local build greater than remote build', next_build.call(['202611025', '20261102']), '202611026')
expect('remote build from a later day', next_build.call(['202611051']), '2026110210')
expect_error('build number that no date-based number can exceed') { next_build.call(['99999999999999']) }
expect('build greater than every known build', TestFlightBuild.greater_build_number?('202611022', latest: ['202611021', nil]), true)
expect('build equal to a known build', TestFlightBuild.greater_build_number?('202611021', latest: ['202611021']), false)
expect('build lower than a TestFlight build', TestFlightBuild.greater_build_number?('20261102', latest: ['202611021']), false)
expect('build with no known build', TestFlightBuild.greater_build_number?('20261102', latest: [0]), true)
expect_error('unsupported build number in the check') { TestFlightBuild.greater_build_number?('1.0', latest: []) }
expect_error('invalid date') { TestFlightBuild.next_build_number(date: '2026-11-02', latest: []) }

revision = 'a' * 40
expect('revision from the newest build notes',
       TestFlightBuild.previous_revision([[], ['No marker'], ["Source revision: #{revision}\n\nChanges"], ["Source revision: #{'b' * 40}"]]),
       revision)
expect('no revision in any notes', TestFlightBuild.previous_revision([[nil], ['Source revision: short']]), nil)

Dir.mktmpdir('testflight-notes') do |root|
  git = lambda do |*args|
    system('git', '-C', root, *args, out: File::NULL, err: File::NULL) || abort('Git fixture failed')
  end
  git.call('init', '-q'); git.call('config', 'user.email', 'test@example.com'); git.call('config', 'user.name', 'Test')
  commit = lambda do |subject|
    git.call('commit', '-q', '--allow-empty', '-m', subject)
    `git -C #{root} rev-parse HEAD`.strip
  end
  first = commit.call('Commit 1')
  (2..24).each { |number| commit.call("Commit #{number}") }
  previous = `git -C #{root} rev-parse HEAD~2`.strip
  head = `git -C #{root} rev-parse HEAD`.strip

  notes = TestFlightBuild.notes(root: root, revision: head, previous_revision: previous)
  expect('notes since the previous revision', notes,
         "Source revision: #{head}\n\nChanges since #{previous[0, 12]}:\n- Commit 24\n- Commit 23")

  notes = TestFlightBuild.notes(root: root, revision: head, previous_revision: nil)
  lines = notes.lines.map(&:chomp)
  expect('notes without a previous revision header', lines.first(3), ["Source revision: #{head}", '', 'Last 20 commits:'])
  expect('notes without a previous revision list', lines.drop(3), (5..24).to_a.reverse.map { |number| "- Commit #{number}" })

  notes = TestFlightBuild.notes(root: root, revision: head, previous_revision: 'c' * 40)
  expect('notes with an unknown previous revision', notes.lines.map(&:chomp).first(4),
         ["Source revision: #{head}", '', "Previous build revision #{'c' * 12} is not in this history.", 'Last 20 commits:'])

  notes = TestFlightBuild.notes(root: root, revision: head, previous_revision: head)
  expect('notes with no new commits', notes, "Source revision: #{head}\n\nChanges since #{head[0, 12]}:\n- No new commits.")

  git.call('checkout', '-q', '-b', 'side', first)
  side = commit.call('Side commit')
  notes = TestFlightBuild.notes(root: root, revision: side, previous_revision: head)
  expect('notes when the previous revision is not an ancestor', notes.lines[2].chomp,
         "Previous build revision #{head[0, 12]} is not in this history.")

  long = TestFlightBuild.notes(root: root, revision: head, previous_revision: first, max_bytes: 120)
  expect('truncated notes keep the source revision', long.lines.first.chomp, "Source revision: #{head}")
  expect('truncated notes fit the limit', long.bytesize <= 120, true)
  expect('truncated notes end with a marker', long.lines.last, '- ...')
  expect('previous revision round trip', TestFlightBuild.previous_revision([[long]]), head)
end

now = 0.0
attempts = 0
result = TestFlightBuild.wait_until(timeout: 90, interval: 30, clock: -> { now }, sleeper: ->(seconds) { now += seconds }) do
  attempts += 1
  attempts == 3 ? :ready : nil
end
expect('wait returns the first ready value', [result, attempts], [:ready, 3])
now = 0.0
attempts = 0
begin
  TestFlightBuild.wait_until(timeout: 90, interval: 30, clock: -> { now }, sleeper: ->(seconds) { now += seconds }) do
    attempts += 1
    nil
  end
  abort 'Expected a timeout'
rescue TestFlightBuild::Timeout
  expect('wait checks until the timeout', [attempts, now], [4, 90.0])
end
puts 'TestFlight build checks passed.'
