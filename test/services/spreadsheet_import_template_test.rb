# frozen_string_literal: true

require "test_helper"

class SpreadsheetImportTemplateTest < ActiveSupport::TestCase
  test "generates a non-empty xlsx with expected headers" do
    binary = SpreadsheetImportTemplate.to_binary
    assert binary.bytesize.positive?
    assert binary.start_with?("PK"), "expected ZIP/xlsx magic bytes"

    book = Roo::Spreadsheet.open(StringIO.new(binary), extension: :xlsx)
    assert_equal "Instructions", book.sheets[0]
    assert_equal "Line Items", book.sheets[1]

    sheet = book.sheet("Line Items")
    headers = sheet.row(1)
    assert_equal SpreadsheetImportTemplate::LINE_ITEM_HEADERS, headers
    assert_includes headers, "Driver"
    assert_includes headers, "Cost Distribution Type"

    SpreadsheetImportTemplate::SAMPLE_ROWS.each_with_index do |_expected, index|
      row = sheet.row(index + 2)
      rate = row[7]
      quantity = row[8]
      forecast = row[1]
      assert_equal forecast, rate * quantity, "row #{index + 2} must satisfy rate * quantity = forecast"
      assert row[11].present?, "row #{index + 2} should include distribution type"
    end
  end
end
