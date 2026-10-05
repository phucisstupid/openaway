cask "openaway" do
  version "0.4.7"
  sha256 "7914b36e40dc16d128ff8efdc5ceda8b3f56c592c871361cdbb9732af94bd3f2"

  url "https://github.com/phucisstupid/openaway/releases/download/v#{version}/OpenAway-macos.zip"
  name "OpenAway"
  desc "Native screen break and wellness reminders"
  homepage "https://github.com/phucisstupid/openaway"

  depends_on macos: :ventura

  app "OpenAway.app"

  caveats <<~EOS
    OpenAway is ad-hoc signed and not notarized.
    If macOS blocks it, open System Settings > Privacy & Security and choose Open Anyway.
  EOS
end
