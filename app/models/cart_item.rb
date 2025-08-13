class CartItem < ApplicationRecord
  # Associations
  belongs_to :cart
  belongs_to :product
  belongs_to :product_variant, optional: true

  # Validations
  validates :quantity, presence: true, numericality: { greater_than: 0 }

  # Callbacks
  after_update :touch_cart
  after_create :touch_cart
  after_destroy :touch_cart

  # Instance methods
  def item_name
    if product_variant.present?
      product_variant.display_name
    else
      product.name
    end
  end

  def item_price
    product_variant&.price || product.price
  end

  def total_price
    quantity * item_price
  end

  def formatted_item_price
    "$#{item_price.to_f}"
  end

  def formatted_total_price
    "$#{total_price.to_f}"
  end

  def item_image
    product_variant&.main_image || product.main_image
  end

  def item_sku
    product_variant&.sku || product.sku
  end

  def item_description
    if product_variant.present?
      product_variant.variant_description
    else
      product.description.truncate(100)
    end
  end

  def in_stock?
    if product_variant.present?
      product_variant.inventory_count >= quantity
    else
      product.inventory_count >= quantity
    end
  end

  def available_quantity
    if product_variant.present?
      product_variant.inventory_count
    else
      product.inventory_count
    end
  end

  def can_increase_quantity?
    available_quantity > quantity
  end

  def max_quantity
    [ available_quantity, 10 ].min # Limit to 10 items max per cart item
  end

  private

  def touch_cart
    cart.touch
  end
end
