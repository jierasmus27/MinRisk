class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.string :name
      t.string :address_line1
      t.string :address_line2
      t.string :city
      t.string :country_iso

      t.timestamps
    end
  end
end
