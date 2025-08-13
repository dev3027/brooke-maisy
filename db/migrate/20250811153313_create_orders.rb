class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.string :order_number, null: false
      t.string :status, default: 'pending'
      t.decimal :total_amount, precision: 10, scale: 2, null: false
      t.text :shipping_address
      t.text :billing_address
      t.string :payment_status, default: 'payment_pending'
      t.string :payment_method
      t.string :stripe_payment_intent_id
      t.text :notes

      t.timestamps
    end

    add_index :orders, :order_number, unique: true
    add_index :orders, :status
    add_index :orders, :payment_status
  end
end
