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

ActiveRecord::Schema[8.1].define(version: 2026_03_21_000600) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "auto_rule_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "created_rule_id", null: false
    t.string "notification_gmail_message_id"
    t.string "source_gmail_message_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["created_rule_id"], name: "index_auto_rule_events_on_created_rule_id"
    t.index ["source_gmail_message_id"], name: "index_auto_rule_events_on_source_gmail_message_id", unique: true
    t.index ["user_id"], name: "index_auto_rule_events_on_user_id"
  end

  create_table "gmail_authentications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "access_token"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "last_refreshed_at"
    t.text "refresh_token"
    t.string "scopes"
    t.string "status", default: "active", null: false
    t.datetime "token_expires_at"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["user_id", "email"], name: "index_gmail_authentications_on_user_id_and_email", unique: true
    t.index ["user_id"], name: "index_gmail_authentications_on_user_id"
  end

  create_table "ntfy_channels", force: :cascade do |t|
    t.string "channel", null: false
    t.datetime "created_at", null: false
    t.string "server_url", default: "https://ntfy.sh", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["user_id"], name: "index_ntfy_channels_on_user_id"
  end

  create_table "rule_applications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "applied_at", null: false
    t.datetime "created_at", null: false
    t.string "gmail_message_id", null: false
    t.jsonb "result", default: {}, null: false
    t.uuid "rule_id", null: false
    t.string "rule_version", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["gmail_message_id", "rule_id", "rule_version"], name: "index_rule_applications_on_message_rule_version", unique: true
    t.index ["rule_id"], name: "index_rule_applications_on_rule_id"
    t.index ["user_id"], name: "index_rule_applications_on_user_id"
  end

  create_table "rules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.jsonb "definition", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "name", null: false
    t.integer "priority", default: 100, null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index "user_id, ((definition)::text)", name: "index_rules_on_user_id_and_definition", unique: true
    t.index ["active", "priority"], name: "index_rules_on_active_and_priority"
    t.index ["definition"], name: "index_rules_on_definition_unique", unique: true
    t.index ["user_id"], name: "index_rules_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "auto_rule_events", "rules", column: "created_rule_id"
  add_foreign_key "auto_rule_events", "users"
  add_foreign_key "gmail_authentications", "users"
  add_foreign_key "ntfy_channels", "users"
  add_foreign_key "rule_applications", "rules"
  add_foreign_key "rule_applications", "users"
  add_foreign_key "rules", "users"
end
