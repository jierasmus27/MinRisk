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
