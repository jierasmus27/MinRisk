# frozen_string_literal: true

class CategoryValue < ApplicationRecord
  has_paper_trail
  belongs_to :project
  has_many :package_risk_drivers, foreign_key: :package_value_id, dependent: :destroy

  enum :dimension, { cost_type: 0, package: 1, wbs: 2, discipline: 3 }, validate: true

  validates :name, presence: true
end
