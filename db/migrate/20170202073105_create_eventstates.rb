class CreateEventstates < ActiveRecord::Migration
  def change
    create_table :eventstates do |t|
      t.integer :timestamp, null: false
      t.integer :object_id, null: false
      t.string :object_type, null: false
      t.timestamps null: false
      t.json :object_changes, null: false
      t.integer :order_id
    end

    add_index "eventstates", ["order_id", "object_type", "object_id", "timestamp"], name: "index_eventstate_on_type_id_timestamp", using: :btree
    add_index "eventstates", ["timestamp"], name: "index_eventstate_timestamp", using: :btree
  end
end
