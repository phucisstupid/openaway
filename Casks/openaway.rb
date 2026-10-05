cask "openaway" do
  version "0.4.8"
  sha256 "7ac3a923b757979ab82998337a9bd4a5afb50a319b1e98d7474110814fb2428b"

  url "https://github.com/phucisstupid/openaway/releases/download/v#{version}/OpenAway-macos-arm64.zip"
  name "OpenAway"
  desc "Native screen break and wellness reminders"
  homepage "https://github.com/phucisstupid/openaway"

  depends_on arch: :arm64
  depends_on macos: :ventura

  app "OpenAway.app"

  caveats <<~EOS
    OpenAway is ad-hoc signed and not notarized.
    If macOS blocks it, open System Settings > Privacy & Security and choose Open Anyway.
  EOS
end
