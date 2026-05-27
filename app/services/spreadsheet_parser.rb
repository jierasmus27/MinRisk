# frozen_string_literal: true

require "bigdecimal"

class SpreadsheetParser
  # Excel / Roo date cells store serials as Date objects; recover the serial for currency fields.
  EXCEL_EPOCH = Date.new(1899, 12, 30)

  HEADER_MAP = {
    "description" => :description,
    "total cost (forecast)" => :total_cost_forecast,
    "cost type" => :cost_type,
    "package" => :package,
    "wbs" => :wbs,
    "discipline" => :discipline,
    "driver" => :driver,
    "rate" => :rate,
    "quantity" => :quantity,
    "total cost (minimum)" => :cost_min,
    "total cost (maximum)" => :cost_max,
    "cost distribution type" => :cost_distribution
  }.freeze

  REQUIRED_FIELDS = %i[total_cost_forecast rate quantity driver].freeze
  REQUIRED_FIELD_LABELS = {
    total_cost_forecast: "Total Cost (Forecast)",
    rate: "Rate",
    quantity: "Quantity",
    driver: "Driver"
  }.freeze
  LINE_ITEMS_SHEET = "Line Items"

  Result = Data.define(
    :file_errors,
    :rows,
    :summary,
    :packages
  ) do
    def success?
      file_errors.empty? && summary[:line_item_count].positive?
    end

    def preview_ready?
      file_errors.empty?
    end

    def commitable?
      preview_ready? && summary[:valid_row_count].to_i.positive?
    end

    def to_h
      {
        "parsed_at" => Time.current.iso8601,
        "file_errors" => file_errors,
        "summary" => summary.stringify_keys,
        "packages" => packages.map { |p| p.stringify_keys },
        "rows" => rows.map { |r| r.deep_stringify_keys }
      }
    end
  end

  def initialize(spreadsheet_import)
    @import = spreadsheet_import
    @project = spreadsheet_import.project
    @currency = @project.currency_iso
  end

  def call
    file_errors = []
    rows = []

    unless @import.file.attached?
      return build_result(file_errors: [ "No file attached" ], rows: [])
    end

    @import.file.open do |tempfile|
      extension = extension_for(@import.file.filename.to_s)
      book = Roo::Spreadsheet.open(tempfile.path, extension: extension, cell_dates: false)
      sheet = find_data_sheet(book)
      unless sheet
        return build_result(file_errors: [ "Could not find a worksheet with line item headers" ], rows: [])
      end

      header_row_number, header_map = locate_header_row(sheet)
      unless header_row_number
        _partial_row, partial_map = locate_best_header_candidate(sheet)
        if partial_map.any?
          missing = REQUIRED_FIELDS.reject { |field| partial_map.key?(field) }
          labels = missing.map { |f| REQUIRED_FIELD_LABELS.fetch(f) }.join(", ")
          return build_result(file_errors: [ "Missing required column(s): #{labels}" ], rows: [])
        end

        return build_result(file_errors: [ "Could not find a worksheet with line item headers" ], rows: [])
      end

      first_data_row = header_row_number + 1
      last_row = sheet.last_row || 0
      (first_data_row..last_row).each do |row_number|
        next if row_blank?(sheet, row_number, header_map)

        rows << parse_row(sheet, row_number, header_map)
      end
    end

    build_result(file_errors: file_errors, rows: rows)
  rescue Roo::HeaderRowNotFoundError, Zip::Error, CSV::MalformedCSVError => e
    build_result(file_errors: [ "Could not read file: #{e.message}" ], rows: [])
  end

  private

  def extension_for(filename)
    case File.extname(filename).downcase
    when ".csv" then :csv
    else :xlsx
    end
  end

  def find_data_sheet(book)
    if book.sheets.include?(LINE_ITEMS_SHEET)
      sheet = book.sheet(LINE_ITEMS_SHEET)
      return sheet if headers_match?(sheet)
    end

    book.sheets.each do |name|
      sheet = book.sheet(name)
      next if sheet.last_row.to_i < 1

      return sheet if headers_match?(sheet)
    end

    nil
  end

  def headers_match?(sheet)
    locate_best_header_candidate(sheet).first.present?
  end

  def locate_header_row(sheet)
    locate_best_header_candidate(sheet, complete: true)
  end

  def locate_best_header_candidate(sheet, complete: false)
    last = [ sheet.last_row.to_i, 1 ].max
    scan_until = [ last, 25 ].min
    best = [ nil, {} ]

    (1..scan_until).each do |row_number|
      map = map_headers(sheet.row(row_number))
      next if map.empty?

      if complete
        next unless REQUIRED_FIELDS.all? { |field| map.key?(field) }

        return [ row_number, map ]
      end

      best = [ row_number, map ] if map.size > best.last.size
    end

    complete ? [ nil, {} ] : best
  end

  def map_headers(header_row)
    header_row.each_with_index.with_object({}) do |(cell, index), map|
      key = HEADER_MAP[normalize_header(cell)]
      map[key] = index if key
    end
  end

  def normalize_header(cell)
    cell.to_s.strip.downcase.gsub(/\s+/, " ")
  end

  def row_blank?(sheet, row_number, header_map)
    extract_values(sheet, row_number, header_map).values.all? { |cell| cell.nil? || cell.to_s.strip.empty? }
  end

  def parse_row(sheet, row_number, header_map)
    values = extract_values(sheet, row_number, header_map)
    errors = []
    warnings = []

    forecast_amount = parse_decimal(values[:total_cost_forecast])
    rate_amount = parse_decimal(values[:rate])
    quantity_amount = parse_decimal(values[:quantity])
    cost_min_amount = parse_decimal(values[:cost_min])
    cost_max_amount = parse_decimal(values[:cost_max])

    forecast_money = monetize_parsed_amount(values[:total_cost_forecast], forecast_amount, errors, "Total Cost (Forecast)")
    rate_money = monetize_parsed_amount(values[:rate], rate_amount, errors, "Rate")
    quantity = quantity_amount
    if values[:quantity].nil? || values[:quantity].to_s.strip.empty?
      errors << "Quantity is required"
    elsif quantity.nil?
      errors << "Quantity is not a valid number"
    end
    cost_min = monetize_parsed_amount(values[:cost_min], cost_min_amount, errors, "Total Cost (Minimum)", required: false)
    cost_max = monetize_parsed_amount(values[:cost_max], cost_max_amount, errors, "Total Cost (Maximum)", required: false)
    distribution = parse_distribution(values[:cost_distribution], errors, warnings)
    driver = parse_driver(values[:driver], errors)

    if formula_without_cached_value?(values[:rate])
      warnings << "Rate formula has no calculated value; save the workbook in Excel before uploading"
    end

    reconcile!(rate_amount, quantity_amount, forecast_amount, errors)
    validate_triangular_bounds!(forecast_money, cost_min, cost_max, errors)
    warnings << "Description is blank" if values[:description].blank?

    {
      row_number: row_number,
      description: values[:description].to_s.strip.presence,
      total_cost_forecast_cents: forecast_money&.cents,
      rate_cents: rate_money&.cents,
      quantity: quantity&.to_s("F"),
      cost_type: values[:cost_type].to_s.strip.presence,
      package: values[:package].to_s.strip.presence,
      wbs: values[:wbs].to_s.strip.presence,
      discipline: values[:discipline].to_s.strip.presence,
      driver: driver,
      cost_min_cents: cost_min&.cents,
      cost_max_cents: cost_max&.cents,
      cost_distribution: distribution,
      errors: errors,
      warnings: warnings,
      valid: errors.empty?
    }
  end

  def extract_values(sheet, row_number, header_map)
    HEADER_MAP.values.uniq.index_with do |field|
      column_index = header_map[field]
      next nil unless column_index

      read_cell_value(sheet, row_number, column_index)
    end
  end

  # Roo uses 1-based row/column indexes. Formula cells return the last calculated value from <v>.
  def read_cell_value(sheet, row_number, column_index)
    return nil unless sheet.respond_to?(:cell)

    column_number = column_index + 1
    value = sheet.cell(row_number, column_number)
    return nil if formula_without_cached_value?(value)

    value
  end

  def formula_without_cached_value?(value)
    value.is_a?(String) && value.strip.start_with?("=")
  end

  def excel_error?(value)
    value.is_a?(String) && value.strip.delete_prefix('"').delete_suffix('"').match?(EXCEL_ERROR_PATTERN)
  end

  def monetize_parsed_amount(raw_value, amount, errors, label, required: true)
    if raw_value.nil? || raw_value.to_s.strip.empty?
      errors << "#{label} is required" if required
      return nil
    end

    if amount.nil?
      errors << if excel_error?(raw_value)
        "#{label} has an Excel error (#{raw_value.to_s.delete_prefix('"').delete_suffix('"')})"
      else
        "#{label} is not a valid number"
      end
      return nil
    end

    Money.from_amount(amount, @currency)
  rescue Money::Currency::UnknownCurrency
    errors << "Project currency is not configured"
    nil
  end

  def parse_driver(value, errors)
    if value.nil? || value.to_s.strip.empty?
      errors << "Driver is required"
      return nil
    end

    normalized = value.to_s.strip.downcase
    normalized = "package" if normalized == "packages"
    unless LineItem::DRIVERS.include?(normalized)
      errors << "Driver must be one of: #{LineItem::DRIVERS.join(', ')}"
      return nil
    end

    normalized
  end

  def parse_distribution(value, errors, warnings)
    return nil if value.nil? || value.to_s.strip.empty?

    normalized = value.to_s.strip.downcase
    unless LineItem::DISTRIBUTION_TYPES.include?(normalized)
      errors << "Cost Distribution Type must be one of: #{LineItem::DISTRIBUTION_TYPES.join(', ')}"
      return nil
    end

    normalized
  end

  def parse_decimal(value)
    value = value.value if value.respond_to?(:value)

    return nil if value.nil?

    return value if value.is_a?(BigDecimal)

    if value.is_a?(Integer)
      return BigDecimal(value.to_s)
    end

    if value.is_a?(Date)
      return BigDecimal((value - EXCEL_EPOCH).to_i)
    end

    if value.is_a?(DateTime) || value.is_a?(Time)
      return BigDecimal((value.to_date - EXCEL_EPOCH).to_i)
    end

    if value.is_a?(Float)
      return BigDecimal(value.to_s)
    end

    if value.is_a?(Rational)
      return BigDecimal(value.numerator) / value.denominator
    end

    if value.is_a?(Numeric)
      return BigDecimal(value.to_s)
    end

    cleaned = value.to_s.strip.delete_prefix('"').delete_suffix('"')
    return nil if excel_error?(cleaned)

    cleaned = cleaned.gsub(/\A\((.*)\)\z/, '-\1') # accounting negatives
    cleaned = cleaned.gsub(/[,$\s\u00A0]/, "")
    return nil if cleaned.empty?

    BigDecimal(cleaned)
  rescue ArgumentError
    nil
  end

  # Compare using full-precision decimals so formula cells (e.g. =B2/H2) reconcile like Excel.
  RECONCILIATION_TOLERANCE = BigDecimal("0.005") # half-cent in project currency major units
  EXCEL_ERROR_PATTERN = /\A#(?:DIV\/0!|REF!|VALUE!|NAME\?|NULL!|NUM!|N\/A)\z/i

  def reconcile!(rate_amount, quantity_amount, forecast_amount, errors)
    return unless rate_amount && quantity_amount && forecast_amount

    diff = (rate_amount * quantity_amount - forecast_amount).abs
    return if diff < RECONCILIATION_TOLERANCE

    errors << "Rate × quantity must exactly equal Total Cost (Forecast)"
  end

  def validate_triangular_bounds!(forecast_money, cost_min, cost_max, errors)
    return unless forecast_money && cost_min && cost_max

    if cost_min > forecast_money || forecast_money > cost_max
      errors << "Total Cost (Minimum) ≤ forecast ≤ Total Cost (Maximum) is required when bounds are set"
    end
  end

  def build_result(file_errors:, rows:)
    valid_rows = rows.select { |r| r[:valid] }
    invalid_rows = rows.reject { |r| r[:valid] }
    warning_count = rows.sum { |r| r[:warnings].size }

    packages = aggregate_packages(valid_rows)

    summary = {
      total_base_cost_cents: valid_rows.sum { |r| r[:total_cost_forecast_cents].to_i },
      line_item_count: rows.size,
      valid_row_count: valid_rows.size,
      invalid_row_count: invalid_rows.size,
      cost_package_count: packages.size,
      warning_count: warning_count,
      error_count: invalid_rows.size + file_errors.size
    }

    Result.new(
      file_errors: file_errors,
      rows: rows,
      summary: summary,
      packages: packages
    )
  end

  def aggregate_packages(valid_rows)
    valid_rows
      .group_by { |r| r[:package].presence || "Unspecified" }
      .map do |name, group|
        {
          name: name,
          line_count: group.size,
          total_forecast_cents: group.sum { |r| r[:total_cost_forecast_cents].to_i },
          status: "ok"
        }
      end
      .sort_by { |p| p[:name] }
  end
end
