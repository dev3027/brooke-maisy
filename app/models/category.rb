class Category < ApplicationRecord
  # Associations
  has_many :products, dependent: :destroy

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  # Callbacks
  before_validation :generate_slug, if: -> { name.present? && slug.blank? }

  # Instance methods
  def to_param
    slug
  end

  def products_count
    products.count
  end

  private

  def generate_slug
    self.slug = name.parameterize
  end
end
