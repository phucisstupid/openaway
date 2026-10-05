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

if Gem::Version.new(version) < Gem::Version.new(versions.first.first)
  puts "Skipping older release #{version}"
  exit
end

updated = contents.sub(/^  version "\d+\.\d+\.\d+"$/, "  version \"#{version}\"")
                  .sub(/^  sha256 "[a-f0-9]{64}"$/, "  sha256 \"#{checksum}\"")
if updated == contents
  puts "Cask is already current"
else
  File.write(path, updated)
  puts "Updated OpenAway cask to #{version}"
end
