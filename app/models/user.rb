class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :omniauthable,
         omniauth_providers: [ :google_oauth2, :facebook ]

  # Role enum
  enum :role, { customer: 0, admin: 1 }

  # Validations
  validates :first_name, presence: true, if: :name_required?
  validates :last_name, presence: true, if: :name_required?
  validates :phone, format: { with: /\A[\+]?[1-9][\d\s\-\(\)]{7,}\z/ }, allow_blank: true
  validates :zip_code, format: { with: /\A\d{5}(-\d{4})?\z/ }, allow_blank: true

  # Associations
  has_many :orders, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :articles, foreign_key: "author_id", dependent: :destroy
  has_many :carts, dependent: :destroy

  # Scopes
  scope :admins, -> { where(role: :admin) }
  scope :customers, -> { where(role: :customer) }

  # Instance methods
  def full_name
    return email if first_name.blank? && last_name.blank?
    "#{first_name} #{last_name}".strip
  end

  def display_name
    full_name.present? ? full_name : email
  end

  def full_address
    return nil if address.blank?
    [ address, city, state, zip_code, country ].compact.join(", ")
  end

  # Social media authentication
  def self.from_omniauth(auth)
    where(email: auth.info.email).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
      user.first_name = auth.info.first_name
      user.last_name = auth.info.last_name
      user.provider = auth.provider
      user.uid = auth.uid
      user.avatar_url = auth.info.image

      # Store additional social profile data
      user.social_profiles = {
        auth.provider => {
          uid: auth.uid,
          name: auth.info.name,
          image: auth.info.image,
          url: auth.info.urls&.dig(auth.provider.capitalize)
        }
      }
    end
  end

  private

  def name_required?
    # Require name for non-social signups or if user is updating profile
    provider.blank? || persisted?
  end
end
