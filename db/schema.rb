# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170202073105) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "events", force: :cascade do |t|
    t.integer  "timestamp",      null: false
    t.integer  "object_id",      null: false
    t.string   "object_type",    null: false
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
    t.json     "object_changes", null: false
    t.integer  "order_id",       null: false
  end

  add_index "events", ["order_id", "object_type", "object_id", "timestamp"], name: "index_events_on_type_id_timestamp", using: :btree
  add_index "events", ["timestamp"], name: "index_events_timestamp", using: :btree

  create_table "eventstates", force: :cascade do |t|
    t.integer  "timestamp",      null: false
    t.integer  "object_id",      null: false
    t.string   "object_type",    null: false
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
    t.json     "object_changes", null: false
    t.integer  "order_id"
  end

  add_index "eventstates", ["order_id", "object_type", "object_id", "timestamp"], name: "index_eventstate_on_type_id_timestamp", using: :btree
  add_index "eventstates", ["timestamp"], name: "index_eventstate_timestamp", using: :btree

  create_table "orders", force: :cascade do |t|
    t.string   "name",                                null: false
    t.string   "status",                              null: false
    t.string   "upload_file_name"
    t.string   "upload_content_type"
    t.integer  "upload_file_size"
    t.datetime "upload_updated_at"
    t.boolean  "visible",             default: false, null: false
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
  end

  add_index "orders", ["status"], name: "index_orders_on_status", using: :btree

end
