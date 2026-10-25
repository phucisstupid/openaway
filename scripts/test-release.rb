#!/usr/bin/env ruby
require "yaml"

root = File.expand_path("..", __dir__)
workflow = YAML.safe_load(File.read(File.join(root, ".github/workflows/release.yml")))
checkout = workflow.fetch("jobs").fetch("release").fetch("steps").first
abort "Release checkout must resolve a tag, not a branch" unless checkout.dig("with", "ref") == 'refs/tags/${{ inputs.tag || github.ref_name }}'
abort "Release jobs must retain queued runs" unless workflow.dig("concurrency", "queue") == "max"

puts "PASS: release tag and queue guards."
