cask "openaway" do
  version "0.5.0"
  sha256 "04f966e5f46d3603645e15a2e9d82e33c0687be585592befcd8a004b4e555645"

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
