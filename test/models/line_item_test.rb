# frozen_string_literal: true

require "test_helper"

class LineItemTest < ActiveSupport::TestCase
  setup do
    company = Company.create!(name: "Test Co", country_iso: "US")
    @project = company.projects.create!(name: "Test Project", currency_iso: "USD", confidence_levels: [ 50 ])
  end

  test "persists money amounts above 32-bit integer limit" do
    large_cents = 3_740_732_600

    line_item = @project.line_items.create!(
      quantity: 1,
      rate_cents: large_cents,
      total_cost_forecast_cents: large_cents
    )

    line_item.reload
    assert_equal large_cents, line_item.rate_cents
    assert_equal large_cents, line_item.total_cost_forecast_cents
  end
end
