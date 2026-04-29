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

ActiveRecord::Schema[8.1].define(version: 2026_04_29_190137) do
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

  create_table "applications", force: :cascade do |t|
    t.string "apply_url"
    t.jsonb "ats_response", default: {}, null: false
    t.string "ats_type", null: false
    t.datetime "created_at", null: false
    t.string "external_id"
    t.jsonb "form_payload", default: {}, null: false
    t.bigint "lead_id", null: false
    t.string "status", default: "draft", null: false
    t.datetime "submitted_at"
    t.datetime "updated_at", null: false
    t.index ["lead_id"], name: "index_applications_on_lead_id", unique: true
  end

  create_table "lead_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "from_stage"
    t.bigint "lead_id", null: false
    t.integer "to_stage", null: false
    t.string "trigger", default: "manual", null: false
    t.datetime "updated_at", null: false
    t.index ["lead_id", "created_at"], name: "index_lead_events_on_lead_id_and_created_at"
    t.index ["lead_id"], name: "index_lead_events_on_lead_id"
  end

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

  create_table "notes", force: :cascade do |t|
    t.string "author", default: "system", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "lead_id", null: false
    t.datetime "updated_at", null: false
    t.index ["lead_id"], name: "index_notes_on_lead_id"
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

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "applications", "leads"
  add_foreign_key "lead_events", "leads"
  add_foreign_key "leads", "profiles"
  add_foreign_key "matching_criterions", "profiles"
  add_foreign_key "notes", "leads"
  add_foreign_key "search_queries", "profiles"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
