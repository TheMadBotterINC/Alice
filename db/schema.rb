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

ActiveRecord::Schema[8.0].define(version: 2026_01_09_210807) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "connectors", force: :cascade do |t|
    t.string "name", null: false
    t.string "connector_type", default: "snowflake", null: false
    t.jsonb "config", default: {}, null: false
    t.integer "status", default: 0, null: false
    t.datetime "last_checked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_connectors_on_name"
    t.index ["status"], name: "index_connectors_on_status"
  end

  create_table "datasets", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "table_name"
    t.jsonb "schema"
    t.bigint "connector_id", null: false
    t.bigint "row_count"
    t.datetime "last_updated_at"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "schema_name"
    t.integer "write_mode"
    t.index ["connector_id"], name: "index_datasets_on_connector_id"
  end

  create_table "pipeline_runs", force: :cascade do |t|
    t.bigint "pipeline_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "started_at", null: false
    t.datetime "completed_at"
    t.integer "duration"
    t.integer "row_count", default: 0
    t.text "error_message"
    t.text "logs"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pipeline_id", "started_at"], name: "index_pipeline_runs_on_pipeline_id_and_started_at"
    t.index ["pipeline_id"], name: "index_pipeline_runs_on_pipeline_id"
    t.index ["started_at"], name: "index_pipeline_runs_on_started_at"
    t.index ["status"], name: "index_pipeline_runs_on_status"
  end

  create_table "pipeline_sources", force: :cascade do |t|
    t.bigint "pipeline_id", null: false
    t.bigint "connector_id"
    t.string "table_alias"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "dataset_id"
    t.index ["connector_id"], name: "index_pipeline_sources_on_connector_id"
    t.index ["dataset_id"], name: "index_pipeline_sources_on_dataset_id"
    t.index ["pipeline_id"], name: "index_pipeline_sources_on_pipeline_id"
    t.check_constraint "connector_id IS NOT NULL AND dataset_id IS NULL OR connector_id IS NULL AND dataset_id IS NOT NULL", name: "pipeline_sources_source_type_check"
  end

  create_table "pipelines", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.text "transformation_sql", null: false
    t.integer "status", default: 0, null: false
    t.string "schedule"
    t.datetime "last_run_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "destination_connector_id"
    t.integer "write_disposition", default: 0, null: false
    t.bigint "destination_dataset_id"
    t.string "export_format"
    t.jsonb "export_options"
    t.integer "source_row_limit", default: 100000, null: false, comment: "Maximum number of rows to load from dataset sources (prevents Snowflake API timeouts)"
    t.boolean "is_template", default: false, null: false
    t.string "merge_key"
    t.jsonb "destination_config", default: {}, null: false
    t.jsonb "transformation_config"
    t.string "transformation_mode", default: "sql", null: false
    t.index ["destination_connector_id"], name: "index_pipelines_on_destination_connector_id"
    t.index ["destination_dataset_id"], name: "index_pipelines_on_destination_dataset_id"
    t.index ["is_template"], name: "index_pipelines_on_is_template"
    t.index ["name"], name: "index_pipelines_on_name"
    t.index ["status"], name: "index_pipelines_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 1, null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "datasets", "connectors"
  add_foreign_key "pipeline_runs", "pipelines"
  add_foreign_key "pipeline_sources", "connectors"
  add_foreign_key "pipeline_sources", "datasets"
  add_foreign_key "pipeline_sources", "pipelines"
  add_foreign_key "pipelines", "connectors", column: "destination_connector_id"
  add_foreign_key "pipelines", "datasets", column: "destination_dataset_id", name: "fk_rails_destination_dataset"
end
