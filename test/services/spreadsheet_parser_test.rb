# frozen_string_literal: true

require "test_helper"

class SpreadsheetParserTest < ActiveSupport::TestCase
  setup do
    company = Company.create!(name: "Test Co", country_iso: "US")
    @project = company.projects.create!(
      name: "Test Project",
      currency_iso: "USD",
      confidence_levels: [ 50 ]
    )
    @import = SpreadsheetImport.create!(project: @project, status: "pending")
    attach_template!(@import)
  end

  test "parses template xlsx into preview_ready summary" do
    result = @import.parse!

    assert @import.reload.preview_ready?
    assert result.commitable?
    assert_empty result.file_errors

    summary = @import.preview_summary
    assert_equal 3, summary["line_item_count"]
    assert_equal 3, summary["valid_row_count"]
    assert_equal 0, summary["invalid_row_count"]
    assert_equal 3, summary["cost_package_count"]
    assert_equal 1_505_000_00, summary["total_base_cost_cents"]
    assert_equal 3, @import.preview_payload["packages"].size
  end

  test "flags reconciliation errors with zero tolerance" do
    binary = build_workbook(
      SpreadsheetImportTemplate::LINE_ITEM_HEADERS,
      [
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

    result = @import.parse!

    assert @import.reload.preview_ready?
    refute result.commitable?
    assert_equal 1, @import.preview_summary["invalid_row_count"]
    row = @import.preview_payload["rows"].first
    assert_includes row["errors"], "Rate × quantity must exactly equal Total Cost (Forecast)"
  end

  test "allows commit when some rows are valid and others invalid" do
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

    result = @import.parse!

    assert @import.reload.preview_ready?
    assert result.commitable?
    refute result.summary[:error_count].zero?
    assert_equal 1, @import.preview_summary["valid_row_count"]
    assert_equal 1, @import.preview_summary["invalid_row_count"]
  end

  test "parses numeric cells returned as Excel dates" do
    parser = SpreadsheetParser.new(@import)
    date_cell = SpreadsheetParser::EXCEL_EPOCH + 125_000

    assert_equal BigDecimal(125_000), parser.send(:parse_decimal, date_cell)

    errors = []
    amount = parser.send(:parse_decimal, date_cell)
    money = parser.send(:monetize_parsed_amount, date_cell, amount, errors, "Total Cost (Forecast)")
    assert_empty errors
    assert_equal 125_000_00, money.cents
  end

  test "parses workbook with date-formatted numeric cells" do
    package = Axlsx::Package.new
    workbook = package.workbook
    date_style = workbook.styles.add_style(format_code: "yyyy-mm-dd")
    workbook.add_worksheet(name: "Line Items") do |sheet|
      sheet.add_row SpreadsheetImportTemplate::LINE_ITEM_HEADERS
      sheet.add_row(
        [ "Test", 125_000, "Direct", "Pkg", "1.1", "Civil", 250, 500, 100_000, 150_000, "Triangular" ],
        style: [ nil, date_style, nil, nil, nil, nil, date_style, date_style, date_style, date_style, nil ]
      )
    end
    attach_binary!(@import, package.to_stream.read)

    result = @import.parse!

    assert @import.reload.preview_ready?
    assert result.commitable?, result.rows.first[:errors].inspect
  end

  test "parses formula cells using cached calculated values" do
    package = Axlsx::Package.new
    sheet = package.workbook.add_worksheet(name: "Line Items")
    sheet.add_row SpreadsheetImportTemplate::LINE_ITEM_HEADERS
    row = sheet.add_row [ "Formula row", 1000, "Direct", "Pkg", "1", "Civil", nil, 100, nil, nil, "Triangular" ]
    rate_cell = row.cells[6]
    rate_cell.formula_value = "B2/H2"
    rate_cell.value = 10

    attach_binary!(@import, package.to_stream.read)

    result = @import.parse!

    assert @import.reload.preview_ready?
    row = result.rows.first
    assert_empty row[:errors], row[:errors].inspect
    assert_in_delta 10.0, row[:rate_cents] / 100.0, 0.01
  end

  test "parses float values from spreadsheets" do
    parser = SpreadsheetParser.new(@import)
    assert_equal BigDecimal("60316.0"), parser.send(:parse_decimal, 60316.0)
  end

  test "fails when required headers are missing" do
    binary = build_workbook(
      %w[Description Rate Quantity],
      [ [ "x", 10, 5 ] ]
    )
    attach_binary!(@import, binary)

    @import.parse!

    assert_equal "failed", @import.reload.status
    assert_includes @import.preview_payload["file_errors"].join, "Missing required column"
  end

  private

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
