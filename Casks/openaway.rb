cask "openaway" do
  version "0.6.2"
  sha256 "d71c95e79801a7df165e4652c1501ae60a0f05d136bcac8e278bcbf88d48f10f"

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
