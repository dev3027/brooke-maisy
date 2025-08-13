class Review < ApplicationRecord
  # Associations
  belongs_to :product
  belongs_to :user

  # Validations
  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :title, presence: true, length: { maximum: 100 }
  validates :content, presence: true, length: { maximum: 1000 }

  # Scopes
  scope :approved, -> { where(approved: true) }
  scope :pending, -> { where(approved: false) }
  scope :by_rating, ->(rating) { where(rating: rating) }
  scope :recent, -> { order(created_at: :desc) }
  scope :helpful, -> { order(helpful_count: :desc) }

  # Instance methods
  def approved?
    approved
  end

  def pending?
    !approved
  end

  def star_rating
    "★" * rating + "☆" * (5 - rating)
  end

  def formatted_date
    created_at.strftime("%B %d, %Y")
  end

  def reviewer_name
    user.display_name
  end

  def reviewer_initials
    name = user.display_name
    name.split.map(&:first).join.upcase
  end

  def helpful?
    helpful_count > 0
  end

  def can_be_marked_helpful_by?(current_user)
    return false if current_user.blank?
    return false if current_user == user
    # TODO: Add logic to prevent multiple helpful marks by same user
    true
  end

  def truncated_content(limit = 150)
    content.length > limit ? "#{content[0..limit]}..." : content
  end

  # Class methods
  def self.average_rating
    return 0 if count.zero?
    average(:rating).to_f.round(1)
  end

  def self.rating_distribution
    group(:rating).count
  end

  def self.rating_percentage(rating)
    total = count
    return 0 if total.zero?
    ((where(rating: rating).count.to_f / total) * 100).round(1)
  end
end
