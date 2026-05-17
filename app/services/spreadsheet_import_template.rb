# frozen_string_literal: true

require "caxlsx"

# Generates the client-facing import workbook (headers + example rows).
#
# Monte Carlo split:
# - Per PROJECT (MinRisk UI / project settings): monte_carlo_iterations, confidence_levels (P10–P90)
# - Per LINE ITEM (this spreadsheet): cost min/max, distribution type (and optional future columns)
class SpreadsheetImportTemplate
  LINE_ITEM_HEADERS = [
    "Description",
    "Total Cost (Forecast)",
    "Cost Type",
    "Package",
    "WBS",
    "Discipline",
    "Rate",
    "Quantity",
    "Total Cost (Minimum)",
    "Total Cost (Maximum)",
    "Cost Distribution Type"
  ].freeze

  # Backward-compatible alias for tests and importers.
  HEADERS = LINE_ITEM_HEADERS

  DISTRIBUTION_TYPES = %w[Triangular Uniform Normal Lognormal].freeze

  # Example rows: rate * quantity must equal Total Cost (Forecast) exactly.
  SAMPLE_ROWS = [
    [
      "Site preparation and earthworks",
      125_000,
      "Direct",
      "01 - Earthworks",
      "1.1",
      "Civil",
      250,
      500,
      100_000,
      150_000,
      "Triangular"
    ],
    [
      "Concrete foundations",
      480_000,
      "Direct",
      "02 - Concrete Substructures",
      "1.2",
      "Structural",
      120,
      4000,
      400_000,
      560_000,
      "Triangular"
    ],
    [
      "Structural steel supply and erect",
      900_000,
      "Direct",
      "03 - Structural Steel",
      "2.1",
      "Structural",
      75,
      12_000,
      750_000,
      1_050_000,
      "Triangular"
    ]
  ].freeze

  FILENAME = "MinRisk_Import_Template.xlsx"

  INSTRUCTIONS = [
    [ "MinRisk import template" ],
    [],
    [ "Where Monte Carlo settings live" ],
    [ "Setting", "Where to configure", "Notes" ],
    [
      "Simulation iterations",
      "Project settings in MinRisk (not this file)",
      "Number of Monte Carlo draws for the whole project"
    ],
    [
      "Confidence levels (P10, P20, … P90)",
      "Project settings in MinRisk (not this file)",
      "Which percentiles to report after simulation"
    ],
    [
      "Cost uncertainty (min / max / distribution)",
      "Line Items sheet columns in this file",
      "One row per cost line; min ≤ forecast ≤ max for triangular"
    ],
    [],
    [ "Line Items sheet columns" ],
    [ "Required", "Description", "Rate × Quantity must equal Total Cost (Forecast) exactly" ],
    [ "Optional (Monte Carlo)", "Total Cost (Minimum), Total Cost (Maximum), Cost Distribution Type",
      "Defaults to Triangular when min/max are present; other types need extra columns later" ],
    [],
    [ "Allowed Cost Distribution Type values", DISTRIBUTION_TYPES.join(", ") ]
  ].freeze

  def self.to_binary
    new.to_binary
  end

  def to_binary
    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: "Instructions") do |sheet|
      INSTRUCTIONS.each { |row| sheet.add_row row }
      sheet.column_widths 28, 36, 48
    end

    workbook.add_worksheet(name: "Line Items") do |sheet|
      number_style = number_cell_style(workbook)
      sheet.add_row LINE_ITEM_HEADERS, style: header_style(workbook)
      SAMPLE_ROWS.each { |row| sheet.add_row row, style: line_item_row_styles(number_style) }
      sheet.column_widths 32, 18, 14, 28, 10, 14, 12, 12, 18, 18, 22
    end

    package.to_stream.read
  end

  private

  def header_style(workbook)
    workbook.styles.add_style(
      b: true,
      bg_color: "D6E3FF",
      fg_color: "001B3D",
      alignment: { horizontal: :center, vertical: :center, wrap_text: true }
    )
  end

  # Force general/number formatting so Excel does not treat cost columns as dates on re-save.
  def number_cell_style(workbook)
    workbook.styles.add_style(format_code: "0.########")
  end

  def line_item_row_styles(number_style)
    [
      nil, # Description
      number_style, # Total Cost (Forecast)
      nil, # Cost Type
      nil, # Package
      nil, # WBS
      nil, # Discipline
      number_style, # Rate
      number_style, # Quantity
      number_style, # Total Cost (Minimum)
      number_style, # Total Cost (Maximum)
      nil # Cost Distribution Type
    ]
  end
end
