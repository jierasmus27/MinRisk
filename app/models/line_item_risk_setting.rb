# frozen_string_literal: true

class LineItemRiskSetting < ApplicationRecord
  include RiskDriverSettings

  belongs_to :line_item

  validates :driver_type, uniqueness: { scope: :line_item_id }
end
