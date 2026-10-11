cask "openaway" do
  version "0.6.3"
  sha256 "dd8fc07b6a0d04c283bf96f0ea7d8de2a4d06328be42fcb3714a3d7113a76ab5"

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
