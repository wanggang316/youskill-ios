require 'open3'

# Network-free rules for TestFlight builds. The beta lanes supply App Store
# Connect data; this module decides the build number and What to Test notes.
module TestFlightBuild
  class Error < StandardError; end
  class Timeout < StandardError; end

  REVISION_PATTERN = /^Source revision: ([0-9a-f]{40})$/.freeze
  FALLBACK_COMMITS = 20
  MAX_NOTES_BYTES = 4000
  MAX_SUFFIX = 99

  # Returns the first number in the date sequence YYYYMMDD, YYYYMMDD1,
  # YYYYMMDD2, ... that is greater than every known build number.
  def self.next_build_number(date:, latest:)
    raise Error, "Invalid build date: #{date}" unless date.to_s.match?(/\A\d{8}\z/)
    highest = highest_build_number(latest)
    candidates = [date.to_s] + (1..MAX_SUFFIX).map { |suffix| "#{date}#{suffix}" }
    candidate = candidates.find { |value| Integer(value, 10) > highest }
    raise Error, "No build number for #{date} is greater than #{highest}." unless candidate
    candidate
  end

  # True when build is greater than every known build number. App Store Connect
  # accepts an upload of a version only with such a number.
  def self.greater_build_number?(build, latest:)
    parse_build_number(build) > highest_build_number(latest)
  end

  def self.highest_build_number(latest)
    latest.compact.map { |value| parse_build_number(value) }.max || 0
  end

  def self.parse_build_number(value)
    text = value.to_s
    raise Error, "Unsupported build number: #{text.inspect}" unless text.match?(/\A\d+\z/)
    Integer(text, 10)
  end

  # notes_by_build holds the What to Test texts of each build, newest build first.
  def self.previous_revision(notes_by_build)
    notes_by_build.each do |notes|
      notes.compact.each do |text|
        match = text.match(REVISION_PATTERN)
        return match[1] if match
      end
    end
    nil
  end

  def self.notes(root:, revision:, previous_revision:, max_bytes: MAX_NOTES_BYTES)
    header = ["Source revision: #{revision}", '']
    if previous_revision && ancestor?(root, previous_revision, revision)
      header << "Changes since #{previous_revision[0, 12]}:"
      subjects = git(root, 'log', '--format=%s', "#{previous_revision}..#{revision}").lines.map(&:chomp)
      subjects = ['No new commits.'] if subjects.empty?
    else
      header << "Previous build revision #{previous_revision[0, 12]} is not in this history." if previous_revision
      header << "Last #{FALLBACK_COMMITS} commits:"
      subjects = git(root, 'log', '--format=%s', '-n', FALLBACK_COMMITS.to_s, revision).lines.map(&:chomp)
    end
    fit(header, subjects.map { |subject| "- #{subject}" }, max_bytes)
  end

  # Calls the block until it returns a truthy value. Raises Timeout after the
  # last check at or past the deadline.
  def self.wait_until(timeout:, interval:, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }, sleeper: ->(seconds) { sleep(seconds) })
    deadline = clock.call + timeout
    loop do
      value = yield
      return value if value
      remaining = deadline - clock.call
      raise Timeout, "Not ready after #{timeout} seconds." if remaining <= 0
      sleeper.call([interval, remaining].min)
    end
  end

  def self.ancestor?(root, ancestor, revision)
    _, _, status = Open3.capture3('git', '-C', root, 'merge-base', '--is-ancestor', ancestor, revision)
    status.success?
  end

  def self.git(root, *args)
    output, error, status = Open3.capture3('git', '-C', root, *args)
    raise Error, "git #{args.first} failed: #{error.strip}" unless status.success?
    output
  end

  # Drops the oldest subjects first so the source revision always stays.
  def self.fit(header, lines, max_bytes)
    text = (header + lines).join("\n")
    return text if text.bytesize <= max_bytes
    kept = lines.dup
    kept.pop until kept.empty? || (header + kept + ['- ...']).join("\n").bytesize <= max_bytes
    (header + kept + ['- ...']).join("\n")
  end
  private_class_method :parse_build_number, :highest_build_number, :ancestor?, :git, :fit
end
