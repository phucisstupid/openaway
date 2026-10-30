#!/usr/bin/env ruby
require "yaml"

root = File.expand_path("..", __dir__)
workflow = YAML.safe_load(File.read(File.join(root, ".github/workflows/release.yml")))
checkout = workflow.fetch("jobs").fetch("release").fetch("steps").first
abort "Release checkout must resolve a tag, not a branch" unless checkout.dig("with", "ref") == 'refs/tags/${{ inputs.tag || github.ref_name }}'
abort "Release jobs must retain queued runs" unless workflow.dig("concurrency", "queue") == "max"

dmg_steps = workflow.fetch("jobs").fetch("create-dmg").fetch("steps")
packaging = dmg_steps.find { |step| step["name"] == "Package and verify DMG" }.fetch("run")
abort "DMG packaging must not add FinderInfo to the signed app" if packaging.include?("--hide-extension")
abort "DMG packaging must verify the mounted app's signature" unless packaging.include?('codesign --verify --deep --strict "$WORK_DIR/mount/OpenAway.app"')
abort "DMG packaging must include the Applications shortcut" unless packaging.include?("--app-drop-link ")
abort "DMG packaging must verify the Applications shortcut" unless packaging.include?('[[ -L "$WORK_DIR/mount/Applications" && "$(readlink "$WORK_DIR/mount/Applications")" == /Applications ]]')

puts "PASS: release tag, queue, and signed DMG guards."
