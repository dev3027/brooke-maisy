class CreateProductVariants < ActiveRecord::Migration[8.0]
  def change
    create_table :product_variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :name
      t.string :sku
      t.decimal :price
      t.integer :inventory_count
      t.string :color
      t.string :size
      t.string :style
      t.boolean :active

      t.timestamps
    end
  end
end
