# Brooke Maisy - Enhanced Features Guide

## Additional Gems for Enhanced Features

Add these to your Gemfile:

```ruby
# AWS S3 Storage
gem 'aws-sdk-s3'

# Social Media Integration
gem 'omniauth'
gem 'omniauth-google-oauth2'
gem 'omniauth-facebook'
gem 'omniauth-rails_csrf_protection'

# Social Sharing & SEO
gem 'social-share-button'
gem 'meta-tags'

# Instagram API (for feed integration)
gem 'instagram_basic_display'

# Image Processing & Optimization
gem 'image_processing', '~> 1.2'
gem 'mini_magick'

# Reviews & Ratings
gem 'acts_as_commentable_with_threading'
```

## AWS S3 Configuration

### Storage Configuration
```ruby
# config/storage.yml
amazon:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: us-east-1
  bucket: brooke-maisy-<%= Rails.env %>
  public: true

# config/environments/production.rb
config.active_storage.variant_processor = :mini_magick
config.active_storage.service = :amazon

# config/environments/development.rb
config.active_storage.service = :local # or :amazon for testing
```

### Credentials Setup
```bash
# Run this command to edit credentials
rails credentials:edit

# Add to credentials file:
aws:
  access_key_id: your_access_key_id
  secret_access_key: your_secret_access_key

google:
  client_id: your_google_client_id
  client_secret: your_google_client_secret

facebook:
  app_id: your_facebook_app_id
  app_secret: your_facebook_app_secret

instagram:
  client_id: your_instagram_client_id
  client_secret: your_instagram_client_secret
```

## Review System Data Models

### Review Migration
```ruby
class CreateReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :reviews do |t|
      t.references :product, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :reviewer_name, null: false
      t.string :reviewer_email, null: false
      t.integer :rating, null: false
      t.text :title
      t.text :content
      t.boolean :verified_purchase, default: false
      t.integer :status, default: 0
      t.integer :helpful_count, default: 0
      t.json :images_data # for customer photos

      t.timestamps
    end

    add_index :reviews, :product_id
    add_index :reviews, :rating
    add_index :reviews, :status
    add_index :reviews, :created_at
  end
end
```

### Review Model
```ruby
class Review < ApplicationRecord
  belongs_to :product
  belongs_to :user, optional: true
  has_many_attached :images

  validates :reviewer_name, presence: true
  validates :reviewer_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :content, presence: true, length: { minimum: 10 }

  enum status: { pending: 0, approved: 1, rejected: 2 }

  scope :approved, -> { where(status: :approved) }
  scope :recent, -> { order(created_at: :desc) }

  def verified_purchase?
    return false unless user.present?
    user.orders.joins(:order_items)
        .where(order_items: { product: product })
        .where(status: [:delivered, :completed])
        .exists?
  end

  before_save :check_verified_purchase

  private

  def check_verified_purchase
    self.verified_purchase = verified_purchase?
  end
end
```

## Social Media Integration

### Omniauth Configuration
```ruby
# config/initializers/omniauth.rb
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, 
           Rails.application.credentials.dig(:google, :client_id),
           Rails.application.credentials.dig(:google, :client_secret)
  
  provider :facebook, 
           Rails.application.credentials.dig(:facebook, :app_id),
           Rails.application.credentials.dig(:facebook, :app_secret)
end
```

### User Model Updates
```ruby
class User < ApplicationRecord
  # Add these fields to users table
  # t.string :provider
  # t.string :uid
  # t.string :avatar_url
  # t.json :social_profiles

  def self.from_omniauth(auth)
    where(email: auth.info.email).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
      user.first_name = auth.info.first_name
      user.last_name = auth.info.last_name
      user.provider = auth.provider
      user.uid = auth.uid
      user.avatar_url = auth.info.image
    end
  end
end
```

### Social Sharing Components
```erb
<!-- app/views/components/social/_share_buttons.html.erb -->
<div class="flex items-center space-x-3">
  <span class="text-sm text-ivory-600 font-medium">Share:</span>
  
  <%= link_to "https://www.facebook.com/sharer/sharer.php?u=#{CGI.escape(url)}", 
      target: "_blank", 
      class: "inline-flex items-center px-3 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors" do %>
    <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 24 24">
      <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
    </svg>
    Facebook
  <% end %>
  
  <%= link_to "https://twitter.com/intent/tweet?url=#{CGI.escape(url)}&text=#{CGI.escape(text)}", 
      target: "_blank",
      class: "inline-flex items-center px-3 py-2 bg-sky-500 text-white rounded-md hover:bg-sky-600 transition-colors" do %>
    <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 24 24">
      <path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"/>
    </svg>
    Twitter
  <% end %>
  
  <%= link_to "https://www.pinterest.com/pin/create/button/?url=#{CGI.escape(url)}&media=#{CGI.escape(image_url)}&description=#{CGI.escape(text)}", 
      target: "_blank",
      class: "inline-flex items-center px-3 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 transition-colors" do %>
    <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 24 24">
      <path d="M12.017 0C5.396 0 .029 5.367.029 11.987c0 5.079 3.158 9.417 7.618 11.174-.105-.949-.199-2.403.041-3.439.219-.937 1.406-5.957 1.406-5.957s-.359-.72-.359-1.781c0-1.663.967-2.911 2.168-2.911 1.024 0 1.518.769 1.518 1.688 0 1.029-.653 2.567-.992 3.992-.285 1.193.6 2.165 1.775 2.165 2.128 0 3.768-2.245 3.768-5.487 0-2.861-2.063-4.869-5.008-4.869-3.41 0-5.409 2.562-5.409 5.199 0 1.033.394 2.143.889 2.741.099.12.112.225.085.345-.09.375-.293 1.199-.334 1.363-.053.225-.172.271-.402.165-1.495-.69-2.433-2.878-2.433-4.646 0-3.776 2.748-7.252 7.92-7.252 4.158 0 7.392 2.967 7.392 6.923 0 4.135-2.607 7.462-6.233 7.462-1.214 0-2.357-.629-2.75-1.378l-.748 2.853c-.271 1.043-1.002 2.35-1.492 3.146C9.57 23.812 10.763 24.009 12.017 24.009c6.624 0 11.99-5.367 11.99-11.988C24.007 5.367 18.641.001 12.017.001z"/>
    </svg>
    Pinterest
  <% end %>
</div>
```

## Instagram Feed Integration

### Instagram Service
```ruby
# app/services/instagram_service.rb
class InstagramService
  include HTTParty
  base_uri 'https://graph.instagram.com'

  def initialize
    @access_token = Rails.application.credentials.dig(:instagram, :access_token)
  end

  def recent_posts(limit = 12)
    response = self.class.get("/me/media", {
      query: {
        fields: 'id,caption,media_type,media_url,thumbnail_url,permalink,timestamp',
        access_token: @access_token,
        limit: limit
      }
    })

    if response.success?
      response.parsed_response['data']
    else
      []
    end
  rescue => e
    Rails.logger.error "Instagram API Error: #{e.message}"
    []
  end
end
```

### Instagram Feed Component
```erb
<!-- app/views/components/social/_instagram_feed.html.erb -->
<div class="bg-ivory-50 py-12">
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="text-center mb-8">
      <h2 class="text-3xl font-bold text-ivory-900 mb-4">Follow Our Journey</h2>
      <p class="text-ivory-600 max-w-2xl mx-auto">
        See behind-the-scenes of our craft creation process and get inspired by our latest creations.
      </p>
      <a href="https://instagram.com/brookemaisy" 
         target="_blank"
         class="inline-flex items-center mt-4 text-ivory-700 hover:text-ivory-900 font-medium">
        <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 24 24">
          <path d="M12.017 0C5.396 0 .029 5.367.029 11.987c0 5.079 3.158 9.417 7.618 11.174-.105-.949-.199-2.403.041-3.439.219-.937 1.406-5.957 1.406-5.957s-.359-.72-.359-1.781c0-1.663.967-2.911 2.168-2.911 1.024 0 1.518.769 1.518 1.688 0 1.029-.653 2.567-.992 3.992-.285 1.193.6 2.165 1.775 2.165 2.128 0 3.768-2.245 3.768-5.487 0-2.861-2.063-4.869-5.008-4.869-3.41 0-5.409 2.562-5.409 5.199 0 1.033.394 2.143.889 2.741.099.12.112.225.085.345-.09.375-.293 1.199-.334 1.363-.053.225-.172.271-.402.165-1.495-.69-2.433-2.878-2.433-4.646 0-3.776 2.748-7.252 7.92-7.252 4.158 0 7.392 2.967 7.392 6.923 0 4.135-2.607 7.462-6.233 7.462-1.214 0-2.357-.629-2.75-1.378l-.748 2.853c-.271 1.043-1.002 2.35-1.492 3.146C9.57 23.812 10.763 24.009 12.017 24.009c6.624 0 11.99-5.367 11.99-11.988C24.007 5.367 18.641.001 12.017.001z"/>
        </svg>
        @brookemaisy
      </a>
    </div>

    <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4" data-controller="instagram-feed">
      <% instagram_posts.each do |post| %>
        <a href="<%= post['permalink'] %>" 
           target="_blank" 
           class="aspect-square bg-ivory-100 rounded-lg overflow-hidden hover:opacity-90 transition-opacity">
          <% if post['media_type'] == 'VIDEO' %>
            <video class="w-full h-full object-cover" muted>
              <source src="<%= post['media_url'] %>" type="video/mp4">
            </video>
          <% else %>
            <img src="<%= post['media_url'] %>" 
                 alt="<%= truncate(post['caption'], length: 100) %>"
                 class="w-full h-full object-cover">
          <% end %>
        </a>
      <% end %>
    </div>
  </div>
</div>
```

## Review System Components

### Product Reviews Section
```erb
<!-- app/views/components/product/_reviews.html.erb -->
<div class="mt-12 border-t border-ivory-200 pt-8">
  <div class="flex items-center justify-between mb-6">
    <h3 class="text-2xl font-bold text-ivory-900">Customer Reviews</h3>
    <button data-action="click->modal#open" 
            data-modal-target="writeReview"
            class="bg-ivory-500 hover:bg-ivory-600 text-white px-4 py-2 rounded-md font-medium">
      Write a Review
    </button>
  </div>

  <!-- Review Summary -->
  <div class="bg-ivory-50 rounded-lg p-6 mb-8">
    <div class="flex items-center space-x-4">
      <div class="text-center">
        <div class="text-3xl font-bold text-ivory-900"><%= product.average_rating.round(1) %></div>
        <div class="flex items-center justify-center mt-1">
          <% 5.times do |i| %>
            <svg class="w-5 h-5 <%= i < product.average_rating ? 'text-yellow-400' : 'text-ivory-300' %>" 
                 fill="currentColor" viewBox="0 0 20 20">
              <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
            </svg>
          <% end %>
        </div>
        <div class="text-sm text-ivory-600 mt-1">
          Based on <%= pluralize(product.reviews.approved.count, 'review') %>
        </div>
      </div>
      
      <div class="flex-1">
        <% 5.downto(1) do |rating| %>
          <div class="flex items-center space-x-2 mb-1">
            <span class="text-sm text-ivory-600 w-8"><%= rating %> star</span>
            <div class="flex-1 bg-ivory-200 rounded-full h-2">
              <div class="bg-yellow-400 h-2 rounded-full" 
                   style="width: <%= product.rating_percentage(rating) %>%"></div>
            </div>
            <span class="text-sm text-ivory-600 w-8">
              <%= product.reviews.approved.where(rating: rating).count %>
            </span>
          </div>
        <% end %>
      </div>
    </div>
  </div>

  <!-- Individual Reviews -->
  <div class="space-y-6">
    <% product.reviews.approved.recent.limit(10).each do |review| %>
      <div class="border-b border-ivory-200 pb-6">
        <div class="flex items-start justify-between mb-3">
          <div>
            <div class="flex items-center space-x-2 mb-1">
              <span class="font-medium text-ivory-900"><%= review.reviewer_name %></span>
              <% if review.verified_purchase? %>
                <span class="bg-green-100 text-green-800 text-xs px-2 py-1 rounded-full">
                  Verified Purchase
                </span>
              <% end %>
            </div>
            <div class="flex items-center space-x-2">
              <div class="flex">
                <% 5.times do |i| %>
                  <svg class="w-4 h-4 <%= i < review.rating ? 'text-yellow-400' : 'text-ivory-300' %>" 
                       fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                  </svg>
                <% end %>
              </div>
              <span class="text-sm text-ivory-500">
                <%= time_ago_in_words(review.created_at) %> ago
              </span>
            </div>
          </div>
        </div>
        
        <% if review.title.present? %>
          <h4 class="font-medium text-ivory-900 mb-2"><%= review.title %></h4>
        <% end %>
        
        <p class="text-ivory-700 mb-3"><%= review.content %></p>
        
        <% if review.images.attached? %>
          <div class="flex space-x-2 mb-3">
            <% review.images.each do |image| %>
              <img src="<%= url_for(image.variant(resize_to_limit: [100, 100])) %>" 
                   alt="Customer photo"
                   class="w-16 h-16 object-cover rounded-md cursor-pointer"
                   data-action="click->lightbox#open">
            <% end %>
          </div>
        <% end %>
        
        <div class="flex items-center space-x-4 text-sm">
          <button class="text-ivory-600 hover:text-ivory-800 flex items-center space-x-1">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 10h4.764a2 2 0 011.789 2.894l-3.5 7A2 2 0 0115.263 21h-4.017c-.163 0-.326-.02-.485-.06L7 20m7-10V5a2 2 0 00-2-2h-.095c-.5 0-.905.405-.905.905 0 .714-.211 1.412-.608 2.006L9 6v4m-2 4h2m8 0V9a2 2 0 00-2-2H9a2 2 0 00-2 2v11a2 2 0 002 2h8a2 2 0 002-2z"/>
            </svg>
            <span>Helpful (<%= review.helpful_count %>)</span>
          </button>
        </div>
      </div>
    <% end %>
  </div>
</div>
```

This enhanced features guide provides comprehensive implementation details for the customer reviews, social media integration, and AWS S3 storage that you requested. The system will create a robust, community-driven platform that showcases your crafts while building customer engagement and social proof.