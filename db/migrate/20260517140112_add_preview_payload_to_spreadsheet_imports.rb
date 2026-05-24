class AddPreviewPayloadToSpreadsheetImports < ActiveRecord::Migration[8.1]
  def change
    add_column :spreadsheet_imports, :preview_payload, :jsonb
  end
end
