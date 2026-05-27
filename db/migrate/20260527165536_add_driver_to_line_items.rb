# frozen_string_literal: true

class AddDriverToLineItems < ActiveRecord::Migration[8.1]
  def up
    add_column :line_items, :driver, :string
    execute <<~SQL.squish
      UPDATE line_items SET driver = 'package' WHERE driver IS NULL
    SQL
    change_column_null :line_items, :driver, false
  end

  def down
    remove_column :line_items, :driver
  end
end
