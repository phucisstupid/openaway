#!/usr/bin/env ruby
require "open3"
require "tmpdir"
require "rbconfig"

UPDATER = File.expand_path("update-cask.rb", __dir__)
OLD_SHA = "a" * 64
NEW_SHA = "b" * 64
BASE = [
  "# Keep this comment and every unrelated setting.",
  'cask "openaway" do',
  '  version "1.9.9"',
  "  sha256 \"#{OLD_SHA}\"",
  '  url "https://github.com/phucisstupid/openaway/releases/download/v#{version}/OpenAway-macos.zip"',
  '  depends_on macos: :ventura',
  '  app "OpenAway.app"',
  "end\n"
].join("\n")

def check(name, source, version, sha, expected, success: true)
  Dir.mktmpdir("openaway-cask-test") do |directory|
    path = File.join(directory, "openaway.rb")
    File.write(path, source)
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, UPDATER, version, sha, path)
    unless status.success? == success && File.read(path) == expected
      abort "FAIL: #{name}\n#{stdout}#{stderr}"
    end
  end
end

updated = BASE.sub('  version "1.9.9"', '  version "1.10.0"').sub(OLD_SHA, NEW_SHA)
check("update only version and checksum", BASE, "1.10.0", NEW_SHA, updated)
check("idempotent repeat", updated, "1.10.0", NEW_SHA, updated)
check("skip downgrade", updated, "1.9.9", OLD_SHA, updated)
check("repair same-version checksum", BASE, "1.9.9", NEW_SHA, BASE.sub(OLD_SHA, NEW_SHA))

[
  ["invalid version", BASE, "1.10.0-beta", NEW_SHA],
  ["invalid checksum length", BASE, "1.10.0", "b" * 63],
  ["uppercase checksum", BASE, "1.10.0", "B" * 64],
  ["missing version", BASE.sub('  version "1.9.9"', ""), "1.10.0", NEW_SHA],
  ["missing checksum", BASE.sub("  sha256 \"#{OLD_SHA}\"", ""), "1.10.0", NEW_SHA],
  ["ambiguous version", BASE + "  version \"1.9.9\"\n", "1.10.0", NEW_SHA],
  ["ambiguous checksum", BASE + "  sha256 \"#{OLD_SHA}\"\n", "1.10.0", NEW_SHA],
  ["malformed extra version", "  version \"invalid\"\n" + BASE, "1.10.0", NEW_SHA],
  ["malformed extra checksum", "  sha256 \"invalid\"\n" + BASE, "1.10.0", NEW_SHA]
].each do |name, source, version, sha|
  check(name, source, version, sha, source, success: false)
end

puts "PASS: 13 cask updater checks."
