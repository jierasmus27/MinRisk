# frozen_string_literal: true

module RiskInputsHelper
  DRIVER_BADGE_CLASSES = {
    "price" => "bg-blue-50 text-blue-700 border border-blue-100",
    "quantity" => "bg-green-50 text-green-700 border border-green-100",
    "design" => "bg-amber-50 text-amber-700 border border-amber-100"
  }.freeze

  DRIVER_VIZ_COLOR_CLASSES = {
    "price" => "text-blue-600",
    "quantity" => "text-green-600",
    "design" => "text-amber-600"
  }.freeze

  def risk_driver_badge_class(driver_type)
    DRIVER_BADGE_CLASSES.fetch(driver_type, "bg-surface-container-high text-on-surface-variant border border-outline-variant")
  end

  def risk_driver_badge_label(driver_type)
    driver_type.to_s.humanize
  end

  def risk_driver_viz_color_class(driver_type)
    DRIVER_VIZ_COLOR_CLASSES.fetch(driver_type, "text-primary")
  end
end
