# frozen_string_literal: true

class SpreadsheetImport < ApplicationRecord
  has_paper_trail
  belongs_to :project
  has_one_attached :file
  has_many :line_items, dependent: :destroy

  STATUSES = %w[pending preview_ready committed failed].freeze

  attribute :status, :string, default: "pending"

  validates :status, inclusion: { in: STATUSES }
  validate :file_content_type, if: -> { file.attached? }

  def parse!
    result = SpreadsheetParser.new(self).call
    update!(
      status: result.preview_ready? ? "preview_ready" : "failed",
      preview_payload: result.to_h
    )
    result
  end

  def preview_summary
    preview_payload&.dig("summary")
  end

  def preview_ready?
    status == "preview_ready"
  end

  def commitable?
    preview_ready? && preview_summary.present? && preview_summary["error_count"].to_i.zero?
  end

  def committed?
    status == "committed"
  end

  def destroy_confirmation_message
    count = line_items.count
    if count.positive?
      "Remove this import and #{count} line item#{'s' unless count == 1}? This cannot be undone."
    elsif committed?
      "Remove this committed import? This cannot be undone."
    else
      "Remove this import preview? This cannot be undone."
    end
  end

  private

  def file_content_type
    allowed = %w[
      application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
      text/csv
      application/csv
    ]
    return if allowed.include?(file.content_type)

    errors.add(:file, "must be an Excel (.xlsx) or CSV file")
  end
end
