cask "openaway" do
  version "0.6.1"
  sha256 "8038684ba39f91953b3dadaf6dcdf4508d438d068f72a820c72dfd32e14a0f26"

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
