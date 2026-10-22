require 'digest'
require 'open3'
require 'fileutils'
require 'json'

module ReleaseCandidate
  # These paths do not contribute to the archived app. Acceptance stays bound to
  # the original revision, including its original test implementation.
  NON_ARTIFACT_PREFIXES = %w[docs/ .agents/ .claude/ Tests/ UITests/].freeze
  RELEASE_TOOL_PATHS = %w[fastlane/Fastfile fastlane/screenshot-selection.json scripts/release-candidate.rb scripts/test-release-candidate.rb].freeze

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
  def self.select_screenshots!(root:, manifest:)
    groups = JSON.parse(File.read(File.join(root, 'fastlane/screenshot-selection.json')))
    prefixes = {'APP_IPHONE_67' => 'phones-iPhone 18 Pro Max-', 'APP_IPHONE_DUO' => 'open-iPhone Duo-'}
    unless groups.is_a?(Hash) && groups.keys.sort == prefixes.keys.sort
      raise ArgumentError, 'Select ordinary iPhone and Duo display groups.'
    end
    screens = groups.map do |group, names|
      prefix = prefixes.fetch(group)
      unless names.is_a?(Array) && names.size.between?(3, 5) && names.uniq == names &&
             names.all? { |name| name.is_a?(String) && File.basename(name) == name && name.start_with?(prefix) && name.end_with?('.png') }
        raise ArgumentError, 'Select three to five distinct screenshots per display group.'
      end
      names.map { |name| name.delete_prefix(prefix) }
    end
    raise ArgumentError, 'Display groups must show the same screens in the same order.' unless screens.uniq.size == 1
    names = groups.values.flatten
    locales = Dir.children(File.join(root, 'fastlane/screenshots')).select do |name|
      File.directory?(File.join(root, 'fastlane/screenshots', name))
    end
    sources = locales.flat_map { |locale| names.map { |name| File.join(root, 'fastlane/screenshots', locale, name) } }
    sources.each do |path|
      digest = manifest.fetch('files')[path]
      raise ArgumentError, "Unverified selected screenshot: #{path}" unless digest && File.file?(path) && Digest::SHA256.file(path).hexdigest == digest
    end
    # A content-addressed directory keeps previous selections intact.
    selection_hash = Digest::SHA256.hexdigest(JSON.generate(sources.to_h { |p| [p, manifest.fetch('files').fetch(p)] }))
    destination = File.join(root, 'build/release/selections', selection_hash)
    sources.each do |source|
      target = File.join(destination, File.basename(File.dirname(source)), File.basename(source))
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(source, target)
    end
    File.write(File.join(destination, 'selection.json'), JSON.pretty_generate(sources.to_h { |p| [p, manifest.fetch('files').fetch(p)] }))
    destination
  end

end
