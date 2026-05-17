# frozen_string_literal: true

namespace :spreadsheet do
  desc "Write the import template XLSX to public/templates (for static hosting or inspection)"
  task write_template: :environment do
    path = Rails.root.join("public/templates", SpreadsheetImportTemplate::FILENAME)
    FileUtils.mkdir_p(path.dirname)
    File.binwrite(path, SpreadsheetImportTemplate.to_binary)
    puts "Wrote #{path}"
  end
end
