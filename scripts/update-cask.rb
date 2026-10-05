require "rubygems"

version, checksum, path = ARGV
abort "Usage: ruby scripts/update-cask.rb VERSION SHA256 CASK_PATH" unless ARGV.length == 3
abort "Invalid release version" unless version.match?(/\A\d+\.\d+\.\d+\z/)
abort "Invalid SHA256" unless checksum.match?(/\A[a-f0-9]{64}\z/)

contents = File.read(path)
versions = contents.scan(/^  version "(\d+\.\d+\.\d+)"$/)
checksums = contents.scan(/^  sha256 "([a-f0-9]{64})"$/)
abort "Expected one version and SHA256 stanza" unless versions.length == 1 && checksums.length == 1 &&
  contents.scan(/^[ \t]*version\b/).length == 1 && contents.scan(/^[ \t]*sha256\b/).length == 1
url_pattern = /^  url "https:\/\/github\.com\/phucisstupid\/openaway\/releases\/download\/v#\{version\}\/OpenAway-macos(?:-arm64)?\.zip"$/
abort "Expected one supported release URL" unless contents.scan(url_pattern).length == 1 &&
  contents.scan(/^[ \t]*url\b/).length == 1
architectures = contents.scan(/^[ \t]*depends_on[ \t]+arch:.*$/)
abort "Unexpected architecture requirement" unless architectures.empty? || architectures == ["  depends_on arch: :arm64"]
abort "Expected one macOS requirement" unless contents.scan(/^  depends_on macos:.*$/).length == 1

if Gem::Version.new(version) < Gem::Version.new(versions.first.first)
  puts "Skipping older release #{version}"
  exit
end

updated = contents.sub(/^  version "\d+\.\d+\.\d+"$/, "  version \"#{version}\"")
                  .sub(/^  sha256 "[a-f0-9]{64}"$/, "  sha256 \"#{checksum}\"")
                  .sub(url_pattern) { |url| url.sub("OpenAway-macos.zip", "OpenAway-macos-arm64.zip") }
if architectures.empty?
  updated = updated.sub(/^  depends_on macos:/, "  depends_on arch: :arm64\n  depends_on macos:")
end
if updated == contents
  puts "Cask is already current"
else
  File.write(path, updated)
  puts "Updated OpenAway cask to #{version}"
end
