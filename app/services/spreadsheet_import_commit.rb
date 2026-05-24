# frozen_string_literal: true

class SpreadsheetImportCommit
  class NotCommittable < StandardError; end

  def initialize(spreadsheet_import)
    @import = spreadsheet_import
    @project = spreadsheet_import.project
    @category_value_cache = {}
  end

  def call
    raise NotCommittable, "Import is not ready to commit" unless @import.ready_for_commit_job?
    raise NotCommittable, "Import has already been committed" if @import.committed?

    preload_category_values!

    ActiveRecord::Base.transaction do
      valid_rows.each { |row| create_line_item!(row) }
      @import.update!(status: "committed", commit_error: nil)
    end

    @import
  end

  private

  def preload_category_values!
    @project.category_values.find_each do |category_value|
      cache_category_value!(category_value.dimension, category_value.name, category_value)
    end
  end

  def valid_rows
    @import.preview_payload.fetch("rows", []).select { |row| row["errors"].blank? }
  end

  def create_line_item!(row)
    @import.line_items.create!(
      project: @project,
      quantity: row["quantity"],
      rate_cents: cents_value(row["rate_cents"]),
      total_cost_forecast_cents: cents_value(row["total_cost_forecast_cents"]),
      cost_min_cents: cents_value(row["cost_min_cents"]),
      cost_max_cents: cents_value(row["cost_max_cents"]),
      cost_distribution: row["cost_distribution"],
      cost_type_value: category_value_for(:cost_type, row["cost_type"]),
      package_value: category_value_for(:package, row["package"]),
      wbs_value: category_value_for(:wbs, row["wbs"]),
      discipline_value: category_value_for(:discipline, row["discipline"])
    )
  end

  def cents_value(raw)
    raw.present? ? raw.to_i : nil
  end

  def category_value_for(dimension, name)
    normalized = name.to_s.strip
    return nil if normalized.blank?

    cache_key = [ dimension.to_s, normalized ]
    return @category_value_cache[cache_key] if @category_value_cache.key?(cache_key)

    category_value = @project.category_values.find_or_create_by!(dimension: dimension, name: normalized)
    cache_category_value!(dimension, normalized, category_value)
  end

  def cache_category_value!(dimension, name, category_value)
    @category_value_cache[[ dimension.to_s, name.to_s.strip ]] = category_value
  end
end
