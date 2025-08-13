class Cart < ApplicationRecord
  # Associations
  belongs_to :user, optional: true
  has_many :cart_items, dependent: :destroy
  has_many :products, through: :cart_items

  # Validations
  validates :session_id, presence: true, if: -> { user.blank? }

  # Scopes
  scope :active, -> { joins(:cart_items) }
  scope :abandoned, -> { where("updated_at < ?", 24.hours.ago) }

  # Instance methods
  def total_items
    cart_items.sum(:quantity)
  end

  def total_price
    cart_items.sum { |item| item.quantity * item.item_price }
  end

  def formatted_total
    "$#{total_price.to_f}"
  end

  def empty?
    cart_items.empty?
  end

  def has_items?
    cart_items.any?
  end

  def add_item(product, product_variant = nil, quantity = 1)
    existing_item = cart_items.find_by(
      product: product,
      product_variant: product_variant
    )

    if existing_item
      existing_item.update(quantity: existing_item.quantity + quantity)
      existing_item
    else
      cart_items.create(
        product: product,
        product_variant: product_variant,
        quantity: quantity
      )
    end
  end

  def remove_item(product, product_variant = nil)
    cart_items.find_by(
      product: product,
      product_variant: product_variant
    )&.destroy
  end

  def update_item_quantity(product, product_variant = nil, quantity = 1)
    item = cart_items.find_by(
      product: product,
      product_variant: product_variant
    )

    if item
      if quantity <= 0
        item.destroy
      else
        item.update(quantity: quantity)
      end
    end
  end

  def clear
    cart_items.destroy_all
  end

  def merge_with(other_cart)
    return unless other_cart

    other_cart.cart_items.each do |item|
      add_item(item.product, item.product_variant, item.quantity)
    end

    other_cart.destroy
  end

  # Class methods
  def self.find_or_create_for_user(user)
    find_or_create_by(user: user)
  end

  def self.find_or_create_for_session(session_id)
    find_or_create_by(session_id: session_id)
  end

  def self.cleanup_abandoned
    abandoned.destroy_all
  end
end
