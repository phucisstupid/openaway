#!/usr/bin/env ruby
require "digest"
require "fileutils"
require "open3"
require "tmpdir"
require "yaml"

ROOT = File.expand_path("..", __dir__)
workflow = YAML.safe_load(File.read(File.join(ROOT, ".github/workflows/release.yml")))
cask_job = workflow.fetch("jobs").fetch("update-cask")
sync = cask_job.fetch("steps").find { |step| step["name"] == "Sync cask with published release" }.fetch("run")
checkout = workflow.fetch("jobs").fetch("release").fetch("steps").first
abort "Release checkout must resolve a tag, not a branch" unless checkout.dig("with", "ref") == 'refs/tags/${{ inputs.tag || github.ref_name }}'
abort "Release and cask jobs must retain queued runs" unless [workflow["concurrency"], cask_job["concurrency"]].all? { |config| config["queue"] == "max" }
abort "Cask archive verification requires a macOS runner" unless cask_job["runs-on"].to_s.start_with?("macos-")
abort "Release archive checks require macOS" unless RUBY_PLATFORM.include?("darwin")

def run!(*command)
  stdout, stderr, status = Open3.capture3(*command)
  abort "#{command.join(' ')} failed:\n#{stdout}#{stderr}" unless status.success?
end

def archive(directory, version: "9.9.9", arch: "arm64", bad_signature: false)
  app = File.join(directory, "OpenAway.app")
  FileUtils.mkdir_p(File.join(app, "Contents/MacOS"))
  plist = File.join(app, "Contents/Info.plist")
  File.write(plist, <<~PLIST)
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
    <key>CFBundleIdentifier</key><string>test.openaway</string>
    <key>CFBundleExecutable</key><string>OpenAway</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>#{version}</string>
    </dict></plist>
  PLIST
  source = File.join(directory, "main.c")
  File.write(source, "int main(void) { return 0; }\n")
  run!("xcrun", "clang", "-arch", arch, source, "-o", File.join(app, "Contents/MacOS/OpenAway"))
  run!("codesign", "--force", "--sign", "-", "--timestamp=none", app)
  File.write(plist, File.read(plist).sub("test.openaway", "test.modified")) if bad_signature
  zip = File.join(directory, "OpenAway-macos-arm64.zip")
  run!("ditto", "-c", "-k", "--keepParent", app, zip)
  checksum = Digest::SHA256.file(zip).hexdigest
  File.write("#{zip}.sha256", "#{checksum}  #{File.basename(zip)}\n")
  checksum
end

Dir.mktmpdir("openaway-release-test") do |directory|
  bin = File.join(directory, "bin")
  FileUtils.mkdir_p(bin)
  gh = File.join(bin, "gh")
  File.write(gh, <<~'MOCK')
    #!/usr/bin/env ruby
    require "fileutils"
    abort "Unexpected gh request" unless ARGV[0] == "release" && ARGV[2] == ENV.fetch("RELEASE_TAG")
    case ARGV[1]
    when "view"
      puts %w[draft prerelease].include?(ENV["RELEASE_KIND"])
    when "download"
      destination = ARGV.fetch(ARGV.index("--dir") + 1)
      matches = ARGV.each_cons(2).select { |flag, _| flag == "--pattern" }
                    .map { |_, pattern| File.join(ENV.fetch("RELEASE_ASSETS"), pattern) }
                    .select { |path| File.file?(path) }
      abort "No matching release assets" if matches.empty?
      FileUtils.cp(matches, destination)
    else
      abort "Unexpected gh request"
    end
  MOCK
  File.chmod(0755, gh)

  fixtures = %w[good older intel bad-signature missing zip-only sha-only checksum].to_h do |name|
    path = File.join(directory, name)
    FileUtils.mkdir_p(path)
    [name, path]
  end
  checksum = archive(fixtures["good"])
  archive(fixtures["older"], version: "9.9.8")
  archive(fixtures["intel"], arch: "x86_64")
  archive(fixtures["bad-signature"], bad_signature: true)
  FileUtils.cp(File.join(fixtures["good"], "OpenAway-macos-arm64.zip"), fixtures["zip-only"])
  FileUtils.cp(File.join(fixtures["good"], "OpenAway-macos-arm64.zip.sha256"), fixtures["sha-only"])
  FileUtils.cp(Dir.glob(File.join(fixtures["good"], "*.zip*")), fixtures["checksum"])
  File.write(File.join(fixtures["checksum"], "OpenAway-macos-arm64.zip.sha256"), "#{'0' * 64}  OpenAway-macos-arm64.zip\n")

  base = File.read(File.join(ROOT, "Casks/openaway.rb"))
             .sub(/^  version ".*"$/, '  version "9.9.8"')
             .sub(/^  sha256 ".*"$/, "  sha256 \"#{'a' * 64}\"")
  current = base.sub('  version "9.9.8"', '  version "9.9.9"').sub('a' * 64, checksum)
  cases = [
    ["publish sync", "good", "v9.9.9", base, current, true, "stable"],
    ["idempotent retry", "good", "v9.9.9", current, current, true, "stable"],
    ["older release", "older", "v9.9.8", current, current, true, "stable"],
    ["draft release", "missing", "v9.9.9", base, base, true, "draft"],
    ["prerelease", "missing", "v9.9.9", base, base, true, "prerelease"],
    ["missing assets", "missing", "v9.9.9", base, base, false, "stable"],
    ["missing checksum", "zip-only", "v9.9.9", base, base, false, "stable"],
    ["missing ZIP", "sha-only", "v9.9.9", base, base, false, "stable"],
    ["wrong checksum", "checksum", "v9.9.9", base, base, false, "stable"],
    ["wrong app version", "older", "v9.9.9", base, base, false, "stable"],
    ["wrong architecture", "intel", "v9.9.9", base, base, false, "stable"],
    ["bad signature", "bad-signature", "v9.9.9", base, base, false, "stable"]
  ]
  cases.each do |name, fixture, tag, source, expected, success, kind|
    Dir.mktmpdir("case-", directory) do |work|
      FileUtils.mkdir_p([File.join(work, "scripts"), File.join(work, "Casks")])
      FileUtils.cp(File.join(ROOT, "scripts/update-cask.rb"), File.join(work, "scripts"))
      cask = File.join(work, "Casks/openaway.rb")
      File.write(cask, source)
      env = { "PATH" => "#{bin}:#{ENV.fetch('PATH')}", "RELEASE_TAG" => tag,
              "RELEASE_ASSETS" => fixtures.fetch(fixture), "RELEASE_KIND" => kind }
      stdout, stderr, status = Open3.capture3(env, "bash", "-c", sync, chdir: work)
      abort "FAIL: #{name}\n#{stdout}#{stderr}" unless status.success? == success && File.read(cask) == expected
    end
  end
  puts "PASS: #{cases.length} release sync checks and tag/queue/runner guards."
end
