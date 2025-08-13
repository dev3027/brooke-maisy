class CreateArticles < ActiveRecord::Migration[8.0]
  def change
    create_table :articles do |t|
      t.string :title, null: false
      t.text :content
      t.text :excerpt
      t.string :slug, null: false
      t.boolean :published, default: false
      t.boolean :featured, default: false
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.string :category
      t.text :tags
      t.string :meta_title
      t.text :meta_description

      t.timestamps
    end

    add_index :articles, :slug, unique: true
    add_index :articles, :published
    add_index :articles, :featured
  end
end
