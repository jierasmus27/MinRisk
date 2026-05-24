# frozen_string_literal: true

class AddCommitErrorToSpreadsheetImports < ActiveRecord::Migration[8.1]
  def change
    add_column :spreadsheet_imports, :commit_error, :string
  end
end
