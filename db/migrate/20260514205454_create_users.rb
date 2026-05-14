class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :operator_id
      t.string :password_digest

      t.timestamps
    end
    add_index :users, :operator_id, unique: true
  end
end
