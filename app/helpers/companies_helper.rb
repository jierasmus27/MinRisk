# frozen_string_literal: true

module CompaniesHelper
  def company_location_label(company)
    parts = [ company.city, company.country_iso ].compact_blank
    parts.any? ? parts.join(", ") : "No location set"
  end

  def company_destroy_confirmation(company)
    count = company.projects.size
    message = "Delete #{company.name}?"
    message += " This will permanently remove #{count} #{'project'.pluralize(count)}." if count.positive?
    message
  end
end
