class CreateEvents < ActiveRecord::Migration
  def change
    create_table :events do |t|
      t.integer :timestamp, null: false
      t.integer :object_id, null: false
      t.string :object_type, null: false
      t.timestamps null: false
      t.json :object_changes, null: false
      t.integer :order_id, null: false
    end

    add_index "events", ["order_id", "object_type", "object_id", "timestamp"], name: "index_events_on_type_id_timestamp", using: :btree
    add_index "events", ["timestamp"], name: "index_events_timestamp", using: :btree
  end
end
