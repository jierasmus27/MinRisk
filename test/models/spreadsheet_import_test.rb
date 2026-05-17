# frozen_string_literal: true

require "test_helper"

class SpreadsheetImportTest < ActiveSupport::TestCase
  setup do
    company = Company.create!(name: "Test Co", country_iso: "US")
    @project = company.projects.create!(name: "Test Project", currency_iso: "USD", confidence_levels: [ 50 ])
    @import = SpreadsheetImport.create!(project: @project, status: "preview_ready")
  end

  test "destroy_confirmation_message for preview without line items" do
    assert_equal "Remove this import preview? This cannot be undone.", @import.destroy_confirmation_message
  end

  test "destroy_confirmation_message includes line item count" do
    @import.line_items.create!(
      project: @project,
      quantity: 1,
      rate_cents: 100,
      total_cost_forecast_cents: 100
    )

    assert_equal "Remove this import and 1 line item? This cannot be undone.", @import.destroy_confirmation_message
  end

  test "destroy cascades to line items" do
    line = @import.line_items.create!(
      project: @project,
      quantity: 2,
      rate_cents: 50,
      total_cost_forecast_cents: 100
    )

    assert_difference -> { LineItem.count }, -1 do
      @import.destroy!
    end

    assert_nil LineItem.find_by(id: line.id)
  end
end
