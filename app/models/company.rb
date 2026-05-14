# frozen_string_literal: true

class Company < ApplicationRecord
  has_paper_trail
  has_many :projects, dependent: :destroy
  has_one_attached :logo

  validates :name, presence: true
  validates :country_iso, presence: true, length: { is: 2 }
  validate :logo_content_type_and_size

  private

  def logo_content_type_and_size
    return unless logo.attached?

    allowed = %w[image/png image/jpeg image/webp]
    unless allowed.include?(logo.content_type)
      errors.add(:logo, "must be PNG, JPEG, or WebP")
      return
    end

    max_bytes = 5.megabytes
    errors.add(:logo, "must be #{max_bytes / 1.megabyte} MB or smaller") if logo.byte_size > max_bytes
  end
end
