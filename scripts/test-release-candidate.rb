#!/usr/bin/env ruby
require 'tmpdir'
require 'fileutils'
require 'json'
require 'digest'
require_relative 'release-candidate'

Dir.mktmpdir do |root|
  Dir.chdir(root) do
    def git(*args)
      system('git', *args, out: File::NULL, err: File::NULL) || abort('Git fixture failed')
    end
    def reject_candidate(label)
      yield
      abort "Expected rejection: #{label}"
    rescue ArgumentError
      puts "Rejected #{label}"
    end
    git('init'); git('config', 'user.email', 'test@example.com'); git('config', 'user.name', 'Test')
    File.write('project.yml', 'version: 1')
    git('add', 'project.yml'); git('commit', '-m', 'Initial candidate')
    revision = `git rev-parse HEAD`.strip
    FileUtils.mkdir_p('build/release'); FileUtils.mkdir_p('fastlane/screenshots/en-US')
    File.write('.gitignore', "build/\nfastlane/screenshots/\n")
    git('add', '.gitignore'); git('commit', '-m', 'Ignore artifacts')
    revision = `git rev-parse HEAD`.strip
    File.write('build/release/App.ipa', 'archive')
    File.write('fastlane/screenshots/en-US/screen.png', 'image')
    manifest = {'revision' => revision, 'version' => '1.1', 'build' => '12', 'files' => {}}
    %w[build/release/App.ipa fastlane/screenshots/en-US/screen.png].each { |p| manifest['files'][File.expand_path(p)] = Digest::SHA256.file(p).hexdigest }
    acceptance = {'revision' => revision, 'version' => '1.1', 'build' => '12', 'working_tree_dirty' => false, 'devices' => %w[Phone Duo].map { |n| {'name' => n} }}
    check = ->(reuse = false) { ReleaseCandidate.validate!(root: root, manifest: manifest, version: '1.1', build: '12', reuse: reuse, acceptance: acceptance, required_devices: %w[Phone Duo]) }
    check.call
    FileUtils.mkdir_p('docs'); File.write('docs/release.md', 'Release notes')
    git('add', 'docs'); git('commit', '-m', 'Document release')
    reject_candidate('different HEAD without opt-in') { check.call }
    check.call(true)
    acceptance['working_tree_dirty'] = true
    reject_candidate('dirty acceptance') { check.call(true) }
    acceptance['working_tree_dirty'] = false
    acceptance['devices'].pop
    reject_candidate('incomplete device matrix') { check.call(true) }
    acceptance['devices'] << {'name' => 'Duo'}
    manifest['build'] = '13'
    reject_candidate('version mismatch') { check.call(true) }
    manifest['build'] = '12'
    File.write('fastlane/screenshots/en-US/extra.png', 'extra')
    reject_candidate('unbound screenshot') { check.call(true) }
    File.delete('fastlane/screenshots/en-US/extra.png')
    File.write('build/release/App.ipa', 'changed')
    reject_candidate('changed archive') { check.call(true) }
    File.write('build/release/App.ipa', 'archive')
    File.write('fastlane/screenshot-selection.json', JSON.generate(['screen.png']))
    reject_candidate('undersized selection') { ReleaseCandidate.select_screenshots!(root: Dir.pwd, manifest: manifest) }
    File.write('fastlane/screenshot-selection.json', JSON.generate(['screen.png', 'missing.png', 'other.png']))
    reject_candidate('unbound selection') { ReleaseCandidate.select_screenshots!(root: Dir.pwd, manifest: manifest) }
    %w[second.png third.png].each do |name|
      p = File.expand_path("fastlane/screenshots/en-US/#{name}")
      File.write(p, name)
      manifest['files'][p] = Digest::SHA256.file(p).hexdigest
    end
    File.write('fastlane/screenshot-selection.json', JSON.generate(%w[screen.png second.png third.png]))
    selected = ReleaseCandidate.select_screenshots!(root: Dir.pwd, manifest: manifest)
    abort 'Selection is incomplete' unless Dir.glob("#{selected}/*/*.png").size == 3
    git('add', 'fastlane/screenshot-selection.json'); git('commit', '-m', 'Select store screenshots')
    check.call(true)
    File.write('project.yml', 'version: 2')
    reject_candidate('dirty source') { check.call(true) }
    git('add', 'project.yml'); git('commit', '-m', 'Change production input')
    reject_candidate('changed production input') { check.call(true) }
    manifest['revision'] = '0' * 40
    reject_candidate('missing source revision') { check.call(true) }
  end
end
puts 'Release candidate checks passed.'
