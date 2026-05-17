# frozen_string_literal: true

module ProjectsHelper
  ESTIMATE_ACCURACY_LABELS = {
    "class_2" => "Class 2 (Detailed)",
    "class_3" => "Class 3 (Semi-Detailed)",
    "class_4" => "Class 4 (Study)"
  }.freeze

  COMMON_CURRENCIES = %w[USD CAD AUD EUR GBP].freeze

  def currency_options
    COMMON_CURRENCIES
  end

  def estimate_accuracy_options
    ESTIMATE_ACCURACY_LABELS.map { |value, label| [ label, value ] }
  end

  def estimate_accuracy_label(project)
    ESTIMATE_ACCURACY_LABELS[project.estimate_accuracy_class] || "—"
  end

  def confidence_level_tags(levels)
    levels.map { |n| "P#{n}" }
  end

  def company_address_html(company)
    lines = [
      company.address_line1,
      company.address_line2,
      [ company.city, company.country_iso ].compact_blank.join(", ")
    ].compact_blank

    safe_join(lines.map { |line| h(line) }, tag.br)
  end

  def project_input_class
    field_input_class
  end

  def project_field_label_class
    field_label_class
  end

  def project_card_class
    card_class
  end

  def project_destroy_confirmation(project)
    "Delete #{project.name}? This will permanently remove all scope data and imports for this project."
  end
end
