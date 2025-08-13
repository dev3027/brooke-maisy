class OrderItem < ApplicationRecord
  # Associations
  belongs_to :order
  belongs_to :product
  belongs_to :product_variant, optional: true

  # Validations
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than: 0 }
  validates :total_price, presence: true, numericality: { greater_than: 0 }

  # Callbacks
  before_validation :calculate_total_price
  before_validation :set_unit_price, if: -> { unit_price.blank? }

  # Instance methods
  def item_name
    if product_variant.present?
      product_variant.display_name
    else
      product.name
    end
  end

  def item_sku
    product_variant&.sku || product.sku
  end

  def item_image
    product_variant&.main_image || product.main_image
  end

  def formatted_unit_price
    "$#{unit_price.to_f}"
  end

  def formatted_total_price
    "$#{total_price.to_f}"
  end

  def item_description
    if product_variant.present?
      product_variant.variant_description
    else
      product.description.truncate(100)
    end
  end

  private

  def calculate_total_price
    if quantity.present? && unit_price.present?
      self.total_price = quantity * unit_price
    end
  end

  def set_unit_price
    if product_variant.present?
      self.unit_price = product_variant.price
    elsif product.present?
      self.unit_price = product.price
    end
  end
end
