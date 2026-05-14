# frozen_string_literal: true

Rails.application.config.x.app_build_label =
  ENV.fetch("MINRISK_BUILD_LABEL", "Build 0.1.0-dev")
