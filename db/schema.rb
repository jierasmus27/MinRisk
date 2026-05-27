# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_27_170056) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "category_values", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "dimension", null: false
    t.string "name", null: false
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "dimension", "name"], name: "index_category_values_on_project_id_and_dimension_and_name", unique: true
    t.index ["project_id"], name: "index_category_values_on_project_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "address_line1"
    t.string "address_line2"
    t.string "city"
    t.string "country_iso"
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "line_items", force: :cascade do |t|
    t.string "cost_distribution"
    t.bigint "cost_max_cents"
    t.bigint "cost_min_cents"
    t.bigint "cost_type_value_id"
    t.datetime "created_at", null: false
    t.bigint "discipline_value_id"
    t.string "driver", null: false
    t.bigint "package_value_id"
    t.bigint "project_id", null: false
    t.decimal "quantity", precision: 24, scale: 8, null: false
    t.bigint "rate_cents", null: false
    t.bigint "spreadsheet_import_id"
    t.bigint "total_cost_forecast_cents", null: false
    t.datetime "updated_at", null: false
    t.bigint "wbs_value_id"
    t.index ["cost_type_value_id"], name: "index_line_items_on_cost_type_value_id"
    t.index ["discipline_value_id"], name: "index_line_items_on_discipline_value_id"
    t.index ["package_value_id"], name: "index_line_items_on_package_value_id"
    t.index ["project_id", "spreadsheet_import_id"], name: "index_line_items_on_project_id_and_spreadsheet_import_id"
    t.index ["project_id"], name: "index_line_items_on_project_id"
    t.index ["spreadsheet_import_id"], name: "index_line_items_on_spreadsheet_import_id"
    t.index ["wbs_value_id"], name: "index_line_items_on_wbs_value_id"
  end

  create_table "package_risk_drivers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "distribution_type", null: false
    t.string "driver_type", null: false
    t.decimal "max_pct", precision: 8, scale: 3, null: false
    t.decimal "min_pct", precision: 8, scale: 3, null: false
    t.decimal "mode_pct", precision: 8, scale: 3, null: false
    t.bigint "package_value_id", null: false
    t.bigint "project_id", null: false
    t.string "source_accuracy_class", null: false
    t.datetime "updated_at", null: false
    t.index ["package_value_id", "driver_type"], name: "index_package_risk_drivers_on_package_value_id_and_driver_type", unique: true
    t.index ["package_value_id"], name: "index_package_risk_drivers_on_package_value_id"
    t.index ["project_id"], name: "index_package_risk_drivers_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.integer "base_year"
    t.string "code"
    t.bigint "company_id", null: false
    t.jsonb "confidence_levels", default: [], null: false
    t.datetime "created_at", null: false
    t.string "currency_iso"
    t.text "description"
    t.string "estimate_accuracy_class"
    t.integer "monte_carlo_iterations", default: 10000, null: false
    t.string "name"
    t.date "start_date"
    t.date "target_end_date"
    t.string "time_zone"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_projects_on_company_id"
  end

  create_table "spreadsheet_imports", force: :cascade do |t|
    t.string "commit_error"
    t.datetime "created_at", null: false
    t.jsonb "preview_payload"
    t.bigint "project_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_spreadsheet_imports_on_project_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "operator_id"
    t.string "password_digest"
    t.datetime "updated_at", null: false
    t.index ["operator_id"], name: "index_users_on_operator_id", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "category_values", "projects"
  add_foreign_key "line_items", "category_values", column: "cost_type_value_id"
  add_foreign_key "line_items", "category_values", column: "discipline_value_id"
  add_foreign_key "line_items", "category_values", column: "package_value_id"
  add_foreign_key "line_items", "category_values", column: "wbs_value_id"
  add_foreign_key "line_items", "projects"
  add_foreign_key "line_items", "spreadsheet_imports"
  add_foreign_key "package_risk_drivers", "category_values", column: "package_value_id"
  add_foreign_key "package_risk_drivers", "projects"
  add_foreign_key "projects", "companies"
  add_foreign_key "spreadsheet_imports", "projects"
end
