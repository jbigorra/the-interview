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

ActiveRecord::Schema[8.1].define(version: 2026_04_28_215031) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "leads", force: :cascade do |t|
    t.string "ats_type"
    t.string "company"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "evaluated_at"
    t.string "fingerprint", null: false
    t.string "location"
    t.text "match_reasoning"
    t.string "match_recommendation"
    t.integer "match_score"
    t.bigint "profile_id", null: false
    t.text "raw_payload", comment: "Original JSON from discovery source"
    t.integer "stage", default: 0, null: false
    t.integer "stage_position", default: 0
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["fingerprint"], name: "index_leads_on_fingerprint", unique: true
    t.index ["profile_id", "stage", "match_score"], name: "idx_leads_for_board_sort"
    t.index ["profile_id", "stage", "stage_position"], name: "index_leads_on_profile_id_and_stage_and_stage_position"
    t.index ["profile_id"], name: "index_leads_on_profile_id"
  end

  create_table "matching_criterions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "excluded_keywords", default: [], array: true
    t.integer "llm_threshold", default: 70
    t.integer "min_salary"
    t.string "preferred_locations", default: [], array: true
    t.bigint "profile_id", null: false
    t.string "required_keywords", default: [], array: true
    t.datetime "updated_at", null: false
    t.string "work_mode", default: "remote"
    t.index ["profile_id"], name: "index_matching_criterions_on_profile_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.jsonb "common_answers", default: {}
    t.text "cover_letter_template"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "full_name", null: false
    t.jsonb "personal_info", default: {}
    t.text "resume_text"
    t.datetime "updated_at", null: false
  end

  create_table "search_queries", force: :cascade do |t|
    t.string "additional_filters"
    t.datetime "created_at", null: false
    t.datetime "last_run_at"
    t.string "portal"
    t.bigint "profile_id", null: false
    t.integer "run_count", default: 0
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["profile_id", "last_run_at"], name: "index_search_queries_on_profile_id_and_last_run_at"
    t.index ["profile_id"], name: "index_search_queries_on_profile_id"
  end

  add_foreign_key "leads", "profiles"
  add_foreign_key "matching_criterions", "profiles"
  add_foreign_key "search_queries", "profiles"
end
