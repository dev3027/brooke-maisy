class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.text :description
      t.decimal :price, precision: 10, scale: 2, null: false
      t.string :sku, null: false
      t.references :category, null: false, foreign_key: true
      t.boolean :active, default: true
      t.boolean :featured, default: false
      t.integer :inventory_count, default: 0
      t.decimal :weight, precision: 8, scale: 2
      t.string :dimensions
      t.text :materials
      t.text :care_instructions
      t.string :slug, null: false

      t.timestamps
    end

    add_index :products, :slug, unique: true
    add_index :products, :sku, unique: true
    add_index :products, :active
    add_index :products, :featured
  end
end
