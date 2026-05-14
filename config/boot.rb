ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# PaperTrail 16.x has not yet updated its ActiveRecord upper bound for 8.1; silence until upstream supports it.
ENV["PT_SILENCE_AR_COMPAT_WARNING"] = "1"

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
