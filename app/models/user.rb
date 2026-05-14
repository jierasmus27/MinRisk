# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  validates :operator_id, presence: true, uniqueness: { case_sensitive: false }
end
