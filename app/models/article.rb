class Article < ApplicationRecord
  # Associations
  belongs_to :author, class_name: "User"
  has_many_attached :images

  # Validations
  validates :title, presence: true
  validates :content, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :excerpt, length: { maximum: 500 }
  validates :meta_title, length: { maximum: 60 }
  validates :meta_description, length: { maximum: 160 }

  # Scopes
  scope :published, -> { where(published: true) }
  scope :featured, -> { where(featured: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_category, ->(category) { where(category: category) if category.present? }
  scope :search, ->(query) { where("title ILIKE ? OR content ILIKE ?", "%#{query}%", "%#{query}%") }

  # Callbacks
  before_validation :generate_slug, if: -> { title.present? && slug.blank? }
  before_validation :generate_excerpt, if: -> { content.present? && excerpt.blank? }
  before_validation :generate_meta_fields

  # Instance methods
  def to_param
    slug
  end

  def published?
    published
  end

  def reading_time
    # Estimate reading time based on average 200 words per minute
    word_count = content.split.size
    (word_count / 200.0).ceil
  end

  def word_count
    content.split.size
  end

  def main_image
    images.attached? ? images.first : nil
  end

  def formatted_published_date
    created_at.strftime("%B %d, %Y")
  end

  def author_name
    author.display_name
  end

  def tag_list
    return [] if tags.blank?
    tags.split(",").map(&:strip)
  end

  def tag_list=(tag_string)
    if tag_string.is_a?(Array)
      self.tags = tag_string.join(", ")
    else
      self.tags = tag_string
    end
  end

  private

  def generate_slug
    base_slug = title.parameterize
    slug_candidate = base_slug
    counter = 1

    while Article.where(slug: slug_candidate).where.not(id: id).exists?
      slug_candidate = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = slug_candidate
  end

  def generate_excerpt
    # Strip HTML tags and truncate to 300 characters
    plain_text = ActionView::Base.full_sanitizer.sanitize(content)
    self.excerpt = plain_text.truncate(300)
  end

  def generate_meta_fields
    self.meta_title = title.truncate(60) if meta_title.blank? && title.present?
    self.meta_description = excerpt.truncate(160) if meta_description.blank? && excerpt.present?
  end
end
