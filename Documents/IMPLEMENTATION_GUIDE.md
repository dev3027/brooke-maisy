# Brooke Maisy - Implementation Guide

## Required Gems

Add these to your Gemfile:

```ruby
# Authentication & Authorization
gem 'devise'
gem 'cancancan'

# E-commerce & Payments
gem 'stripe'
gem 'money-rails'

# Image Processing
gem 'image_processing', '~> 1.2'

# SEO & Content
gem 'friendly_id'
gem 'meta-tags'
gem 'sitemap_generator'

# Admin Interface (optional - can build custom)
gem 'rails_admin', optional: true

# Development & Testing
group :development, :test do
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'rspec-rails'
end

group :development do
  gem 'annotate'
  gem 'letter_opener'
end
```

## Tailwind Configuration

Update `config/tailwind.config.js`:

```javascript
const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}',
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter var', ...defaultTheme.fontFamily.sans],
      },
      colors: {
        ivory: {
          50: '#fefdfb',
          100: '#fdf9f3',
          200: '#faf2e7',
          300: '#f6e8d7',
          400: '#f0d9c3',
          500: '#e8c7a6',
          600: '#d4a574',
          700: '#b8834a',
          800: '#8f6238',
          900: '#6b4a2a'
        },
        pastel: {
          pink: '#f8d7da',
          lavender: '#e2d5f1',
          mint: '#d1f2eb',
          peach: '#fdebd0',
          sky: '#cce7ff',
          sage: '#e8f5e8'
        }
      },
      animation: {
        'fade-in': 'fadeIn 0.5s ease-in-out',
        'slide-up': 'slideUp 0.3s ease-out',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%': { transform: 'translateY(10px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        }
      }
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/container-queries'),
  ]
}
```

## Database Migrations

### Users Table (Devise + Custom Fields)
```ruby
class DeviseCreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :first_name
      t.string :last_name
      t.integer :role, default: 0
      t.string :phone
      t.text :address
      t.string :city
      t.string :state
      t.string :zip_code
      t.string :country, default: 'US'

      t.string   :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at

      t.timestamps null: false
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :role
  end
end
```

### Categories Table
```ruby
class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :image_url
      t.integer :sort_order, default: 0
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :categories, :slug, unique: true
    add_index :categories, :active
    add_index :categories, :sort_order
  end
end
```

### Products Table
```ruby
class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.text :description
      t.text :short_description
      t.string :sku, null: false
      t.decimal :base_price, precision: 10, scale: 2, null: false
      t.decimal :compare_at_price, precision: 10, scale: 2
      t.integer :inventory_count, default: 0
      t.boolean :track_inventory, default: true
      t.integer :status, default: 0
      t.boolean :featured, default: false
      t.references :category, null: false, foreign_key: true
      t.json :tags
      t.decimal :weight, precision: 8, scale: 2
      t.string :dimensions
      t.text :care_instructions
      t.integer :views_count, default: 0

      t.timestamps
    end

    add_index :products, :sku, unique: true
    add_index :products, :status
    add_index :products, :featured
    add_index :products, :category_id
    add_index :products, :created_at
  end
end
```

## Component Structure Examples

### Product Card Component
```erb
<!-- app/views/components/product/_card.html.erb -->
<div class="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow duration-300">
  <div class="aspect-square relative">
    <%= image_tag product.images.attached? ? product.images.first : 'placeholder.jpg',
        class: "w-full h-full object-cover",
        alt: product.name %>
    <% if product.featured? %>
      <span class="absolute top-2 left-2 bg-pastel-pink text-ivory-800 px-2 py-1 rounded-full text-xs font-medium">
        Featured
      </span>
    <% end %>
  </div>
  
  <div class="p-4">
    <h3 class="font-medium text-ivory-900 mb-2">
      <%= link_to product.name, product_path(product), class: "hover:text-ivory-700" %>
    </h3>
    
    <p class="text-ivory-600 text-sm mb-3 line-clamp-2">
      <%= product.short_description %>
    </p>
    
    <div class="flex items-center justify-between">
      <div class="flex items-center space-x-2">
        <span class="text-lg font-semibold text-ivory-900">
          $<%= product.base_price %>
        </span>
        <% if product.compare_at_price.present? && product.compare_at_price > product.base_price %>
          <span class="text-sm text-ivory-500 line-through">
            $<%= product.compare_at_price %>
          </span>
        <% end %>
      </div>
      
      <%= button_to "Add to Cart", cart_items_path, 
          params: { product_id: product.id },
          method: :post,
          class: "bg-ivory-500 hover:bg-ivory-600 text-white px-3 py-1 rounded-md text-sm transition-colors",
          form: { data: { turbo_frame: "cart-summary" } } %>
    </div>
  </div>
</div>
```

### Navigation Component
```erb
<!-- app/views/components/layout/_navigation.html.erb -->
<nav class="bg-ivory-50 shadow-sm sticky top-0 z-50">
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="flex justify-between items-center h-16">
      <!-- Logo -->
      <div class="flex-shrink-0">
        <%= link_to root_path, class: "flex items-center space-x-2" do %>
          <span class="text-2xl font-bold text-ivory-800">Brooke Maisy</span>
        <% end %>
      </div>
      
      <!-- Main Navigation -->
      <div class="hidden md:flex items-center space-x-8">
        <%= link_to "Shop", products_path, 
            class: "text-ivory-700 hover:text-ivory-900 font-medium" %>
        <%= link_to "Blog", articles_path, 
            class: "text-ivory-700 hover:text-ivory-900 font-medium" %>
        <%= link_to "About", about_path, 
            class: "text-ivory-700 hover:text-ivory-900 font-medium" %>
        <%= link_to "Contact", contact_path, 
            class: "text-ivory-700 hover:text-ivory-900 font-medium" %>
      </div>
      
      <!-- User Actions -->
      <div class="flex items-center space-x-4">
        <!-- Cart -->
        <%= turbo_frame_tag "cart-summary" do %>
          <%= link_to cart_path, class: "relative p-2 text-ivory-700 hover:text-ivory-900" do %>
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                    d="M3 3h2l.4 2M7 13h10l4-8H5.4m0 0L7 13m0 0l-1.5 6M7 13l-1.5 6m0 0h9"></path>
            </svg>
            <% if current_cart&.items&.any? %>
              <span class="absolute -top-1 -right-1 bg-pastel-pink text-ivory-800 rounded-full w-5 h-5 flex items-center justify-center text-xs font-medium">
                <%= current_cart.items.sum(:quantity) %>
              </span>
            <% end %>
          <% end %>
        <% end %>
        
        <!-- User Menu -->
        <% if user_signed_in? %>
          <div class="relative" data-controller="dropdown">
            <button data-action="click->dropdown#toggle" 
                    class="flex items-center space-x-1 text-ivory-700 hover:text-ivory-900">
              <span><%= current_user.first_name || current_user.email %></span>
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
              </svg>
            </button>
            
            <div data-dropdown-target="menu" 
                 class="hidden absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg py-1 z-50">
              <%= link_to "My Account", account_path, 
                  class: "block px-4 py-2 text-sm text-ivory-700 hover:bg-ivory-50" %>
              <%= link_to "Order History", orders_path, 
                  class: "block px-4 py-2 text-sm text-ivory-700 hover:bg-ivory-50" %>
              <% if current_user.admin? %>
                <%= link_to "Admin Dashboard", admin_root_path, 
                    class: "block px-4 py-2 text-sm text-ivory-700 hover:bg-ivory-50" %>
              <% end %>
              <%= button_to "Sign Out", destroy_user_session_path, 
                  method: :delete,
                  class: "block w-full text-left px-4 py-2 text-sm text-ivory-700 hover:bg-ivory-50" %>
            </div>
          </div>
        <% else %>
          <%= link_to "Sign In", new_user_session_path, 
              class: "text-ivory-700 hover:text-ivory-900 font-medium" %>
        <% end %>
      </div>
    </div>
  </div>
</nav>
```

## Stimulus Controllers

### Dropdown Controller
```javascript
// app/javascript/controllers/dropdown_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.close = this.close.bind(this)
  }

  toggle(event) {
    event.preventDefault()
    
    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    document.addEventListener("click", this.close)
  }

  close(event) {
    if (event && this.element.contains(event.target)) {
      return
    }
    
    this.menuTarget.classList.add("hidden")
    document.removeEventListener("click", this.close)
  }
}
```

### Cart Controller
```javascript
// app/javascript/controllers/cart_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["quantity", "total"]
  static values = { productId: Number, price: Number }

  updateQuantity(event) {
    const quantity = parseInt(event.target.value)
    const total = (quantity * this.priceValue).toFixed(2)
    
    if (this.hasQuantityTarget) {
      this.quantityTarget.textContent = quantity
    }
    
    if (this.hasTotalTarget) {
      this.totalTarget.textContent = `$${total}`
    }

    // Update cart via Turbo
    this.updateCart(quantity)
  }

  async updateCart(quantity) {
    try {
      const response = await fetch(`/cart/items/${this.productIdValue}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ quantity: quantity })
      })

      if (response.ok) {
        // Turbo will handle the response and update the cart summary
      }
    } catch (error) {
      console.error('Error updating cart:', error)
    }
  }
}
```

## Routes Structure

```ruby
# config/routes.rb
Rails.application.routes.draw do
  devise_for :users
  root 'home#index'

  # Public routes
  resources :products, only: [:index, :show] do
    collection do
      get :search
    end
  end
  
  resources :categories, only: [:show]
  resources :articles, only: [:index, :show] do
    resources :comments, only: [:create]
  end
  
  # Cart and checkout
  resource :cart, only: [:show] do
    resources :items, controller: 'cart_items'
  end
  
  resources :orders, only: [:show, :create] do
    member do
      get :confirmation
    end
  end
  
  # User account
  resource :account, only: [:show, :edit, :update]
  resources :orders, only: [:index, :show], path: 'my-orders'
  
  # Static pages
  get 'about', to: 'pages#about'
  get 'contact', to: 'pages#contact'
  post 'contact', to: 'pages#create_contact'
  
  # Admin routes
  namespace :admin do
    root 'dashboard#index'
    resources :products
    resources :categories
    resources :orders
    resources :articles
    resources :users
    resources :analytics, only: [:index]
  end
  
  # API routes for future mobile app
  namespace :api do
    namespace :v1 do
      resources :products, only: [:index, :show]
      resources :categories, only: [:index, :show]
    end
  end
end
```

This implementation guide provides the concrete technical details needed to build the Brooke Maisy crafts store. The architecture emphasizes Rails conventions, clean component organization, and a scalable foundation for future growth.