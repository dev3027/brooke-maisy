class Product < ApplicationRecord
  # Associations
  belongs_to :category
  has_many :product_variants, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :order_items, dependent: :destroy
  has_many :cart_items, dependent: :destroy
  has_many_attached :images

  # Validations
  validates :name, presence: true
  validates :description, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :sku, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  validates :inventory_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :weight, numericality: { greater_than: 0 }, allow_blank: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :featured, -> { where(featured: true) }
  scope :in_stock, -> { where("inventory_count > 0") }
  scope :by_category, ->(category) { where(category: category) }
  scope :search, ->(query) { where("name ILIKE ? OR description ILIKE ?", "%#{query}%", "%#{query}%") }

  # Callbacks
  before_validation :generate_slug, if: -> { name.present? && slug.blank? }
  before_validation :generate_sku, if: -> { sku.blank? }

  # Instance methods
  def to_param
    slug
  end

  def in_stock?
    inventory_count > 0
  end

  def out_of_stock?
    inventory_count <= 0
  end

  def low_stock?(threshold = 5)
    inventory_count <= threshold
  end

  def average_rating
    return 0 if reviews.approved.empty?
    reviews.approved.average(:rating).to_f.round(1)
  end

  def reviews_count
    reviews.approved.count
  end

  def main_image
    images.attached? ? images.first : nil
  end

  def display_price
    "$#{price.to_f}"
  end

  def formatted_weight
    return nil unless weight.present?
    "#{weight} oz"
  end

  def has_variants?
    product_variants.active.any?
  end

  def available_variants
    product_variants.active.in_stock
  end

  def total_inventory
    if has_variants?
      product_variants.active.sum(:inventory_count)
    else
      inventory_count
    end
  end

  private

  def generate_slug
    base_slug = name.parameterize
    slug_candidate = base_slug
    counter = 1

    while Product.where(slug: slug_candidate).where.not(id: id).exists?
      slug_candidate = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = slug_candidate
  end

  def generate_sku
    # Generate SKU based on category and product name
    category_code = category&.name&.first(3)&.upcase || "PRD"
    name_code = name.present? ? name.gsub(/[^a-zA-Z0-9]/, "").first(4).upcase : "ITEM"
    random_suffix = SecureRandom.hex(3).upcase

    self.sku = "#{category_code}-#{name_code}-#{random_suffix}"
  end
end
