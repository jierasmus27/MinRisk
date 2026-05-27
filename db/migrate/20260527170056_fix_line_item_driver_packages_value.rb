# frozen_string_literal: true

class FixLineItemDriverPackagesValue < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE line_items SET driver = 'package' WHERE driver = 'packages'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE line_items SET driver = 'packages' WHERE driver = 'package'
    SQL
  end
end
