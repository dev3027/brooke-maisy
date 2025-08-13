class CreateReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :reviews do |t|
      t.references :product, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :rating, null: false
      t.string :title
      t.text :content
      t.boolean :verified_purchase, default: false
      t.integer :helpful_count, default: 0
      t.boolean :approved, default: false

      t.timestamps
    end

    add_index :reviews, :rating
    add_index :reviews, :approved
  end
end
