# frozen_string_literal: true

require "test_helper"

class SpreadsheetImportCommitTest < ActiveSupport::TestCase
  setup do
    company = Company.create!(name: "Test Co", country_iso: "US")
    @project = company.projects.create!(name: "Test Project", currency_iso: "USD", confidence_levels: [ 50 ])
    @import = SpreadsheetImport.create!(project: @project, status: "preview_ready")
    attach_template!(@import)
    @import.parse!
  end

  test "commits valid rows and creates category values" do
    assert_difference -> { @project.line_items.count }, +3 do
      assert_difference -> { @project.category_values.count }, +9 do
        SpreadsheetImportCommit.new(@import).call
      end
    end

    assert @import.reload.committed?
    assert_equal 3, @import.line_items.count
  end

  test "skips invalid rows on partial import" do
    binary = build_workbook(
      SpreadsheetImportTemplate::LINE_ITEM_HEADERS,
      [
        SpreadsheetImportTemplate::SAMPLE_ROWS.first,
        [
          "Bad row",
          1000,
          "Direct",
          "Pkg",
          "1",
          "Civil",
          10,
          50,
          nil,
          nil,
          nil
        ]
      ]
    )
    attach_binary!(@import, binary)
    @import.parse!

    assert @import.commitable?
    refute @import.fully_valid?

    assert_difference -> { @project.line_items.count }, +1 do
      SpreadsheetImportCommit.new(@import).call
    end

    assert @import.reload.committed?
  end

  test "raises when import is already committed" do
    SpreadsheetImportCommit.new(@import).call

    assert_raises(SpreadsheetImportCommit::NotCommittable) do
      SpreadsheetImportCommit.new(@import.reload).call
    end
  end

  test "raises when import is not commitable" do
    @import.update!(
      status: "preview_ready",
      preview_payload: @import.preview_payload.merge(
        "summary" => @import.preview_summary.merge(
          "valid_row_count" => 0,
          "invalid_row_count" => 3
        )
      )
    )

    assert_raises(SpreadsheetImportCommit::NotCommittable) do
      SpreadsheetImportCommit.new(@import).call
    end
  end

  test "commits rows with money values above 32-bit integer limit" do
    @import.update!(
      preview_payload: {
        "rows" => [
          {
            "row_number" => 2,
            "quantity" => "1",
            "rate_cents" => 3_740_732_600,
            "total_cost_forecast_cents" => 3_740_732_600,
            "cost_min_cents" => nil,
            "cost_max_cents" => nil,
            "cost_distribution" => nil,
            "cost_type" => nil,
            "package" => nil,
            "wbs" => nil,
            "discipline" => nil,
            "errors" => []
          }
        ],
        "summary" => {
          "valid_row_count" => 1,
          "invalid_row_count" => 0
        }
      }
    )

    SpreadsheetImportCommit.new(@import).call

    line_item = @import.line_items.sole
    assert_equal 3_740_732_600, line_item.rate_cents
    assert_equal 3_740_732_600, line_item.total_cost_forecast_cents
  end

  test "caches category values across rows with shared dimensions" do
    queries = count_queries do
      SpreadsheetImportCommit.new(@import).call
    end

    # Three template rows share cost types/packages/etc.; cache should avoid repeated lookups.
    assert_operator queries[:category_value_loads], :<=, 20
  end

  private

  def count_queries
    counts = { category_value_loads: 0 }
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      sql = payload[:sql]
      counts[:category_value_loads] += 1 if sql.match?(/SELECT "category_values"/)
    end

    yield

    counts
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  def attach_template!(import)
    attach_binary!(import, SpreadsheetImportTemplate.to_binary)
  end

  def attach_binary!(import, binary)
    import.file.attach(
      io: StringIO.new(binary),
      filename: "import.xlsx",
      content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
  end

  def build_workbook(header_row, data_rows)
    package = Axlsx::Package.new
    workbook = package.workbook
    workbook.add_worksheet(name: "Line Items") do |sheet|
      sheet.add_row header_row
      data_rows.each { |row| sheet.add_row row }
    end
    package.to_stream.read
  end
end
