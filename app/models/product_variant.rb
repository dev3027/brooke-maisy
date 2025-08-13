class ProductVariant < ApplicationRecord
  # Associations
  belongs_to :product
  has_many :order_items, dependent: :destroy
  has_many :cart_items, dependent: :destroy
  has_many_attached :images

  # Validations
  validates :name, presence: true
  validates :sku, presence: true, uniqueness: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :inventory_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :in_stock, -> { where("inventory_count > 0") }
  scope :by_color, ->(color) { where(color: color) if color.present? }
  scope :by_size, ->(size) { where(size: size) if size.present? }
  scope :by_style, ->(style) { where(style: style) if style.present? }

  # Callbacks
  before_validation :generate_sku, if: -> { sku.blank? }
  before_validation :set_default_price, if: -> { price.blank? }

  # Instance methods
  def in_stock?
    inventory_count > 0
  end

  def out_of_stock?
    inventory_count <= 0
  end

  def low_stock?(threshold = 5)
    inventory_count <= threshold
  end

  def display_price
    "$#{price.to_f}"
  end

  def display_name
    variant_attributes = [ color, size, style ].compact
    if variant_attributes.any?
      "#{product.name} - #{variant_attributes.join(', ')}"
    else
      name.present? ? "#{product.name} - #{name}" : product.name
    end
  end

  def variant_description
    attributes = []
    attributes << "Color: #{color}" if color.present?
    attributes << "Size: #{size}" if size.present?
    attributes << "Style: #{style}" if style.present?
    attributes.join(", ")
  end

  def main_image
    if images.attached?
      images.first
    else
      product.main_image
    end
  end

  private

  def generate_sku
    base_sku = product.sku
    variant_code = [ color&.first, size&.first, style&.first ].compact.join.upcase
    variant_code = name.present? ? name.gsub(/[^a-zA-Z0-9]/, "").first(3).upcase : "VAR" if variant_code.blank?

    self.sku = "#{base_sku}-#{variant_code}"
  end

  def set_default_price
    self.price = product.price if product.present?
  end
end
