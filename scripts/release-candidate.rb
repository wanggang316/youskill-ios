require 'digest'
require 'open3'

module ReleaseCandidate
  # These paths do not contribute to the archived app. Acceptance stays bound to
  # the original revision, including its original test implementation.
  NON_ARTIFACT_PREFIXES = %w[docs/ .agents/ .claude/ Tests/ UITests/].freeze
  RELEASE_TOOL_PATHS = %w[fastlane/Fastfile scripts/release-candidate.rb scripts/test-release-candidate.rb].freeze

  def self.validate!(root:, manifest:, version:, build:, reuse:, acceptance:, required_devices:)
    root = File.realpath(root)
    git = lambda do |*args|
      output, _, status = Open3.capture3('git', '-C', root, *args)
      raise ArgumentError, 'Cannot verify release source history.' unless status.success?
      output
    end
    raise ArgumentError, 'Commit release inputs first.' unless git.call('status', '--porcelain').strip.empty?
    revision = manifest.fetch('revision')
    raise ArgumentError, 'Invalid source revision.' unless revision.match?(/\A[0-9a-f]{40}\z/)
    unless manifest.fetch('version') == version && manifest.fetch('build') == build
      raise ArgumentError, 'Release version or build changed.'
    end
    head = git.call('rev-parse', 'HEAD').strip
    if head != revision
      raise ArgumentError, 'Source changed after acceptance. Set reuse_prepared:true only for unchanged app inputs.' unless reuse
      git.call('merge-base', '--is-ancestor', revision, head)
      changed = git.call('diff', '--name-only', '--no-renames', '-z', revision, head).split("\0")
      blocked = changed.reject { |p| NON_ARTIFACT_PREFIXES.any? { |prefix| p.start_with?(prefix) } || RELEASE_TOOL_PATHS.include?(p) }
      raise ArgumentError, "Release inputs changed: #{blocked.join(', ')}" unless blocked.empty?
      unless acceptance && acceptance.values_at('revision', 'version', 'build', 'working_tree_dirty') == [revision, version, build, false]
        raise ArgumentError, 'Missing clean acceptance for the prepared candidate.'
      end
      missing = required_devices - acceptance.fetch('devices').map { |d| d.fetch('name') }
      raise ArgumentError, "Incomplete acceptance: #{missing.join(', ')}" unless missing.empty?
    end
    files = manifest.fetch('files')
    raise ArgumentError, 'Expected exactly one IPA.' unless files.keys.count { |p| p.end_with?('.ipa') } == 1
    files.each do |path, digest|
      raise ArgumentError, "Release asset changed: #{path}" unless File.file?(path) && Digest::SHA256.file(path).hexdigest == digest
    end
    screenshots = Dir.glob(File.join(root, 'fastlane/screenshots/*/*.png')).sort
    unless !screenshots.empty? && screenshots == files.keys.select { |p| p.end_with?('.png') }.sort
      raise ArgumentError, 'Screenshot inventory changed.'
    end
    {source_revision: revision, release_revision: head, reused: head != revision}
  end
end
