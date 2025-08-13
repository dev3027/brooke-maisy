# Brooke Maisy Admin Interface Implementation Guide
## Phase 3: Step-by-Step Implementation Instructions

### Overview

This guide provides detailed, actionable instructions for implementing the complete admin interface architecture outlined in [`ADMIN_ARCHITECTURE.md`](ADMIN_ARCHITECTURE.md). Each section includes code examples, file locations, and testing instructions.

---

## Phase 1: Foundation Setup (Week 1-2)

### Step 1.1: Create Admin Namespace Structure

**1.1.1 Update Routes Configuration**

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Existing routes...
  devise_for :users, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks"
  }
  
  root "home#index"
  
  # Admin namespace with authentication constraint
  constraints lambda { |request| 
    user = request.env['warden']&.user
    user&.admin?
  } do
    namespace :admin do
      root "dashboard#index"
      
      get "dashboard", to: "dashboard#index"
      get "analytics", to: "dashboard#analytics"
      
      resources :products do
        member do
          patch :toggle_active
          patch :toggle_featured
          post :duplicate
        end
        
        collection do
          get :bulk_edit
          patch :bulk_update
          delete :bulk_destroy
          get :export
          post :import
        end
        
        resources :images, only: [:create, :update, :destroy] do
          member do
            patch :set_primary
            patch :reorder
          end
        end
        
        resources :variants, controller: 'product_variants'
      end
      
      resources :categories do
        member do
          patch :toggle_active
          patch :move_up
          patch :move_down
        end
        
        collection do
          post :reorder
        end
      end
      
      resources :orders, only: [:index, :show, :update] do
        member do
          patch :update_status
          patch :update_payment_status
          post :send_tracking_email
          get :print_invoice
        end
      end
      
      resources :customers, controller: 'users'
      resources :reviews, only: [:index, :show, :update, :destroy] do
        member do
          patch :approve
          patch :reject
        end
      end
      
      resources :articles
      resources :admin_users, only: [:index, :show, :new, :create, :destroy]
    end
  end
  
  # Existing public routes...
end
```

**1.1.2 Create Admin Directory Structure**

```bash
# Create admin controller directories
mkdir -p app/controllers/admin
mkdir -p app/views/admin
mkdir -p app/views/layouts/admin
mkdir -p app/helpers/admin
mkdir -p app/javascript/controllers/admin
```

### Step 1.2: Implement Base Admin Controller

**1.2.1 Create Base Admin Controller**

```ruby
# app/controllers/admin/base_controller.rb
class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :set_admin_context
  
  layout 'admin/application'
  
  protected
  
  def ensure_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: 'Access denied. Admin privileges required.'
    end
  end
  
  def set_admin_context
    @admin_context = true
    @page_title = controller_name.humanize
    @breadcrumbs = []
  end
  
  def set_page_title(title)
    @page_title = title
  end
  
  def add_breadcrumb(name, path = nil)
    @breadcrumbs << { name: name, path: path }
  end
  
  def handle_admin_error(exception)
    Rails.logger.error "Admin Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    
    respond_to do |format|
      format.html { redirect_to admin_root_path, alert: 'An error occurred. Please try again.' }
      format.json { render json: { error: 'An error occurred' }, status: :unprocessable_entity }
    end
  end
  
  private
  
  def admin_params_filter(params, allowed_keys)
    params.require(:admin).permit(allowed_keys)
  rescue ActionController::ParameterMissing
    {}
  end
end
```

**1.2.2 Update Application Controller**

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # Add admin helper method
  def admin_signed_in?
    user_signed_in? && current_user.admin?
  end
  
  helper_method :admin_signed_in?
end
```

### Step 1.3: Configure CanCanCan Authorization

**1.3.1 Create Ability Model**

```ruby
# app/models/ability.rb
class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new # Guest user
    
    if user.admin?
      admin_abilities(user)
    else
      customer_abilities(user)
    end
  end

  private

  def admin_abilities(user)
    # Full admin access to admin panel
    can :access, :admin_panel
    can :read, :admin_dashboard
    can :read, :admin_analytics
    
    # Product management
    can :manage, Product
    can :manage, ProductVariant
    can :manage, Category
    can [:bulk_edit, :bulk_update, :bulk_destroy, :export, :import], Product
    can [:toggle_active, :toggle_featured, :duplicate], Product
    
    # Order management
    can :read, Order
    can :update, Order
    can [:update_status, :update_payment_status, :send_tracking_email, :print_invoice], Order
    
    # Customer management
    can :read, User
    can :update, User, role: 'customer'
    
    # Review management
    can :manage, Review
    can [:approve, :reject], Review
    
    # Content management
    can :manage, Article
    
    # Admin user management
    can :read, User, role: 'admin'
    can :create, User
    cannot :destroy, User, id: user.id # Can't delete self
  end

  def customer_abilities(user)
    # Customer abilities (existing)
    can :read, Product, active: true
    can :read, Category, active: true
    can :read, Article, published: true
    
    if user.persisted?
      can :manage, Order, user: user
      can :manage, Review, user: user
      can :manage, Cart, user: user
      can :update, User, id: user.id
    end
  end
end
```

**1.3.2 Update Base Admin Controller with Authorization**

```ruby
# app/controllers/admin/base_controller.rb (add to existing)
class Admin::BaseController < ApplicationController
  # ... existing code ...
  
  # Add CanCanCan integration
  check_authorization unless: :devise_controller?
  
  rescue_from CanCan::AccessDenied do |exception|
    respond_to do |format|
      format.html { redirect_to admin_root_path, alert: exception.message }
      format.json { render json: { error: exception.message }, status: :forbidden }
    end
  end
  
  protected
  
  def ensure_admin!
    authorize! :access, :admin_panel
  end
  
  # ... rest of existing code ...
end
```

### Step 1.4: Create Admin Layout

**1.4.1 Create Admin Application Layout**

```erb
<!-- app/views/layouts/admin/application.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <title><%= @page_title ? "#{@page_title} - " : "" %>Admin - Brooke Maisy</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="mobile-web-app-capable" content="yes">
    <meta name="robots" content="noindex, nofollow">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= yield :head %>

    <link rel="icon" href="/icon.png" type="image/png">
    <link rel="icon" href="/icon.svg" type="image/svg+xml">
    <link rel="apple-touch-icon" href="/icon.png">

    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body class="bg-gray-50 min-h-screen">
    <!-- Admin Header -->
    <%= render 'admin/shared/header' %>
    
    <div class="flex h-screen pt-16">
      <!-- Admin Sidebar -->
      <%= render 'admin/shared/sidebar' %>
      
      <!-- Main Content -->
      <main class="flex-1 overflow-y-auto">
        <!-- Breadcrumbs -->
        <% if @breadcrumbs.any? %>
          <%= render 'admin/shared/breadcrumbs' %>
        <% end %>
        
        <!-- Flash Messages -->
        <%= render 'shared/flash_messages' %>
        
        <!-- Page Content -->
        <div class="p-6">
          <%= yield %>
        </div>
      </main>
    </div>
  </body>
</html>
```

**1.4.2 Create Admin Header Partial**

```erb
<!-- app/views/admin/shared/_header.html.erb -->
<header class="bg-white shadow-sm border-b border-gray-200 fixed top-0 left-0 right-0 z-50">
  <div class="flex items-center justify-between h-16 px-6">
    <!-- Logo and Title -->
    <div class="flex items-center space-x-4">
      <%= link_to admin_root_path, class: "flex items-center space-x-2" do %>
        <div class="w-8 h-8 bg-gradient-to-br from-pastel-pink to-pastel-lavender rounded-full flex items-center justify-center">
          <span class="text-ivory-800 font-bold text-sm">BM</span>
        </div>
        <span class="text-xl font-bold text-gray-800">Admin Panel</span>
      <% end %>
    </div>
    
    <!-- Search Bar -->
    <div class="flex-1 max-w-md mx-8">
      <%= form_with url: admin_products_path, method: :get, local: true, class: "relative" do |f| %>
        <%= f.text_field :search, 
            placeholder: "Search products, orders, customers...",
            value: params[:search],
            class: "w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-pastel-pink focus:border-transparent" %>
        <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
          <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
          </svg>
        </div>
      <% end %>
    </div>
    
    <!-- User Menu -->
    <div class="flex items-center space-x-4">
      <!-- Notifications -->
      <button class="relative p-2 text-gray-600 hover:text-gray-900 transition-colors">
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-5 5v-5z"></path>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 7h6a2 2 0 012 2v9a2 2 0 01-2 2H9l-5-5V9a2 2 0 012-2z"></path>
        </svg>
        <span class="absolute -top-1 -right-1 bg-red-500 text-white rounded-full w-5 h-5 flex items-center justify-center text-xs font-medium">
          3
        </span>
      </button>
      
      <!-- User Dropdown -->
      <div class="relative" data-controller="dropdown">
        <button data-action="click->dropdown#toggle" 
                class="flex items-center space-x-2 text-gray-700 hover:text-gray-900 transition-colors">
          <% if current_user.avatar_url.present? %>
            <img src="<%= current_user.avatar_url %>" 
                 alt="<%= current_user.display_name %>"
                 class="w-8 h-8 rounded-full">
          <% else %>
            <div class="w-8 h-8 bg-pastel-mint rounded-full flex items-center justify-center">
              <span class="text-ivory-800 font-medium text-sm">
                <%= current_user.display_name.first.upcase %>
              </span>
            </div>
          <% end %>
          <span class="font-medium"><%= current_user.first_name || current_user.email.split('@').first %></span>
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
          </svg>
        </button>
        
        <div data-dropdown-target="menu" 
             class="hidden absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg py-1 z-50 border border-gray-200">
          <%= link_to "View Site", root_path, target: "_blank",
              class: "block px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 transition-colors" %>
          <%= link_to "My Profile", "#", 
              class: "block px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 transition-colors" %>
          <div class="border-t border-gray-200 my-1"></div>
          <%= button_to "Sign Out", destroy_user_session_path, 
              method: :delete,
              class: "block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 transition-colors" %>
        </div>
      </div>
    </div>
  </div>
</header>
```

**1.4.3 Create Admin Sidebar Navigation**

```erb
<!-- app/views/admin/shared/_sidebar.html.erb -->
<aside class="w-64 bg-white shadow-sm border-r border-gray-200 overflow-y-auto">
  <nav class="mt-6">
    <!-- Dashboard -->
    <%= link_to admin_root_path, 
        class: "flex items-center px-6 py-3 text-gray-700 hover:bg-gray-50 hover:text-gray-900 transition-colors #{'bg-gray-50 text-gray-900' if current_page?(admin_root_path)}" do %>
      <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2H5a2 2 0 00-2-2z"></path>
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5a2 2 0 012-2h4a2 2 0 012 2v6H8V5z"></path>
      </svg>
      Dashboard
    <% end %>
    
    <!-- Products Section -->
    <div class="mt-6">
      <h3 class="px-6 text-xs font-semibold text-gray-500 uppercase tracking-wider">Products</h3>
      <div class="mt-2">
        <%= link_to admin_products_path, 
            class: "flex items-center px-6 py-2 text-sm text-gray-700 hover:bg-gray-50 hover:text-gray-900 transition-colors #{'bg-gray-50 text-gray-900' if controller_name == 'products'}" do %>
          <svg class="w-4 h-4 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"></path>
          </svg>
          All Products
        <% end %>
        
        <%= link_to admin_categories_path, 
            class: "flex items-center px-6 py-2 text-sm text-gray-700 hover:bg-gray-50 hover:text-gray-900 transition-colors #{'bg-gray-50 text-gray-900' if controller_name == 'categories'}" do %>
          <svg class="w-4 h-4 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path>
          </svg>
          Categories
        <% end %>
        
        <%= link_to new_admin_product_path, 
            class: "flex items-center px-6 py-2 text-sm text-gray-700 hover:bg-gray-50 hover:text-gray-900 transition-colors" do %>
          <svg class="w-4 h-4 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
          </svg>
          Add Product
        <% end %>
      </div>
    </div>
    
    <!-- Orders Section -->
    <div class="mt-6">
      <h3 class="px-6 text-xs font-semibold text-gray-500 uppercase tracking-wider">Orders</h3>
      <div class="mt-2">
        <%= link_to admin_orders_path, 
            class: "flex items-center px-6 py-2 text-sm text-gray-700 hover:bg-gray-50 hover:text-gray-900 transition-colors #{'bg-gray-50 text-gray-900' if controller_name == 'orders'}" do %>
          <svg class="w-4 h-4 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"></path>
          </svg>
          All Orders
        <% end %>
      </div>
    </div>
    
    <!-- Customers Section -->
    <div class="mt-6">
      <h3 class="px-6 text-xs font-semibold text-gray-500 uppercase tracking-wider">Customers</h3>
      <div class="mt-2">
        <%= link_to admin_customers_path, 
            class: "flex items-center px-6 py-2 text-sm text-gray-700 hover:bg-gray-50 hover:text-gray-900 transition-colors #{'bg-gray-50 text-gray-900' if controller_name == 'users'}" do %>
          <svg class="w-4 h-4 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"></path>
          </svg>
          All Customers
        <% end %>
      </div>
    </div>
    
    <!-- Reviews Section -->
    <div class="mt-6">
      <h3 class="px-6 text-xs font-semibold text-gray-500 uppercase tracking-wider">Reviews</h3>
      <div class="mt-2">
        <%= link_to admin_reviews_path, 
            class: "flex items-center px-6 py-2 text-sm text-gray-700 hover:bg-gray-50 hover:text-gray-900 transition-colors #{'bg-gray-50 text-gray-900' if controller_name == 'reviews'}" do %>
          <svg class="w-4 h-4 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"></path>
          </svg>
          All Reviews
        <% end %>
      </div>
    </div>
    
    <!-- Content Section -->
    <div class="mt-6">
      <h3 class="px-6 text-xs font-semibold text-gray-500 uppercase tracking-wider">Content</h3>
      <div class="mt-2">
        <%= link_to admin_articles_path, 
            class: "flex items-center px-6 py-2 text-sm text-gray-700 hover:bg-gray-50 hover:text-gray-900 transition-colors #{'bg-gray-50 text-gray-900' if controller_name == 'articles'}" do %>
          <svg class="w-4 h-4 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9.5a2.5 2.5 0 00-2.5-2.5H15"></path>
          </svg>
          Blog Articles
        <% end %>
      </div>
    </div>
  </nav>
</aside>
```

**1.4.4 Create Breadcrumbs Partial**

```erb
<!-- app/views/admin/shared/_breadcrumbs.html.erb -->
<div class="bg-white border-b border-gray-200 px-6 py-4">
  <nav class="flex" aria-label="Breadcrumb">
    <ol class="flex items-center space-x-4">
      <li>
        <%= link_to admin_root_path, class: "text-gray-500 hover:text-gray-700 transition-colors" do %>
          <svg class="flex-shrink-0 h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
            <path d="M10.707 2.293a1 1 0 00-1.414 0l-7 7a1 1 0 001.414 1.414L4 10.414V17a1 1 0 001 1h2a1 1 0 001-1v-2a1 1 0 011-1h2a1 1 0 011 1v2a1 1 0 001 1h2a1 1 0 001-1v-6.586l.293.293a1 1 0 001.414-1.414l-7-7z"></path>
          </svg>
          <span class="sr-only">Home</span>
        <% end %>
      </li>
      
      <% @breadcrumbs.each_with_index do |crumb, index| %>
        <li>
          <div class="flex items-center">
            <svg class="flex-shrink-0 h-5 w-5 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"></path>
            </svg>
            <% if crumb[:path] && index < @breadcrumbs.length - 1 %>
              <%= link_to crumb[:name], crumb[:path], class: "ml-4 text-sm font-medium text-gray-500 hover:text-gray-700 transition-colors" %>
            <% else %>
              <span class="ml-4 text-sm font-medium text-gray-900"><%= crumb[:name] %></span>
            <% end %>
          </div>
        </li>
      <% end %>
    </ol>
  </nav>
</div>
```

### Step 1.5: Create Dashboard Controller and View

**1.5.1 Create Dashboard Controller**

```ruby
# app/controllers/admin/dashboard_controller.rb
class Admin::DashboardController < Admin::BaseController
  def index
    authorize! :read, :admin_dashboard
    
    set_page_title("Dashboard")
    
    # Load dashboard metrics
    @metrics = load_dashboard_metrics
    @recent_orders = load_recent_orders
    @low_stock_products = load_low_stock_products
    @recent_reviews = load_recent_reviews
  end
  
  def analytics
    authorize! :read, :admin_analytics
    
    set_page_title("Analytics")
    add_breadcrumb("Analytics")
    
    # Load analytics data
    @analytics_data = load_analytics_data
  end
  
  private
  
  def load_dashboard_metrics
    {
      total_products: Product.count,
      active_products: Product.active.count,
      total_orders: Order.count,
      pending_orders: Order.pending.count,
      total_customers: User.customers.count,
      total_revenue: Order.completed.sum(:total_amount),
      pending_reviews: Review.where(approved: false).count
    }
  end
  
  def load_recent_orders
    Order.includes(:user, :order_items)
         .recent
         .limit(10)
  end
  
  def load_low_stock_products
    Product.active
           .where('inventory_count <= ?', 5)
           .includes(:category)
           .limit(10)
  end
  
  def load_recent_reviews
    Review.includes(:user, :product)
          .where(approved: false)
          .order(created_at: :desc)
          .limit(5)
  end
  
  def load_analytics_data
    # Implement analytics data loading
    # This would include charts data, trends, etc.
    {}
  end
end
```

**1.5.2 Create Dashboard View**

```erb
<!-- app/views/admin/dashboard/index.html.erb -->
<div class="space-y-6">
  <!-- Page Header -->
  <div class="flex items-center justify-between">
    <h1 class="text-2xl font-bold text-gray-900">Dashboard</h1>
    <div class="flex space-x-3">
      <%= link_to "View Site", root_path, target: "_blank",
          class: "inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 transition-colors" %>
      <%= link_to "Add Product", new_admin_product_path,
          class: "inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-pastel-pink hover:bg-opacity-90 transition-colors" %>
    </div>
  </div>
  
  <!-- Metrics Cards -->
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
    <!-- Total Products -->
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <svg class="h-8 w-8 text-pastel-pink" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"></path>
            </svg>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Total Products</dt>
              <dd class="text-lg font-medium text-gray-900"><%= @metrics[:total_products] %></dd>
            </dl>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Active Products -->
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <svg class="h-8 w-8 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Active Products</dt>
              <dd class="text-lg font-medium text-gray-900"><%= @metrics[:active_products] %></dd>
            </dl>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Total Orders -->
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <svg class="h-8 w-8 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"></path>
            </svg>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Total Orders</dt>
              <dd class="text-lg font-medium text-gray-900"><%= @metrics[:total_orders] %></dd>
            </dl>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Total Revenue -->
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <svg class="h-8 w-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"></path>
            </svg>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Total Revenue</dt>
              <dd class="text-lg font-medium text-gray-900">$<%= number_with_precision(@metrics[:total_revenue], precision: 2) %></dd>
            </dl>
          </div>
        </div>
      </div>
    </div>
  </div>
  
  <!-- Content Grid -->
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
    <!-- Recent Orders -->
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Recent Orders</h3>
        <div class="space-y-3">
          <% @recent_orders.each do |order| %>
            <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
              <div>
                <p class="text-sm font-medium text-gray-900"><%= order.order_number %></p>
                <p class="text-sm text-gray-500"><%= order.user.display_name %></p>
              </div>
              <div class="text-right">
                <p class="text-sm font-medium text-gray-900"><%= order.formatted_total %></p>
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-<%= order.status_color %>-100 text-<%= order.status_color %>-800">
                  <%= order.status.humanize %>
                </span>
              </div>
            </div>
          <% end %>
        </div>
        <div class="mt-4">
          <%= link_to "View All Orders", admin_orders_path, class: "text-sm font-medium text-pastel-pink hover:text-opacity-80" %>
        </div>
      </div>
    </div>
    
    <!-- Low Stock Products -->
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Low Stock Alert</h3>
        <div class="space-y-3">
          <% @low_stock_products.each do |product| %>
            <div class="flex items-center justify-between p-3 bg-red-50 rounded-lg">
              <div>
                <p class="text-sm font-medium text-gray-900"><%= product.name %></p>
                <p class="text-sm text-gray-500"><%= product.category.name %></p>
              </div>
              <div class="text-right">
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                  <%= product.inventory_count %> left
                </span>
              </div>
            </div>
          <% end %>
        </div>
        <div class="mt-4">
          <%= link_to "Manage Inventory", admin_products_path(filter: 'low_stock'), class: "text-sm font-medium text-pastel-pink hover:text-opacity-80" %>
        </div>
      </div>
    </div>
  </div>
</div>
```

---

## Phase 2: Product Management System (Week 3-4)

### Step 2.1: Create Products Controller

**2.1.1 Products Controller Implementation**

```ruby
# app/controllers/admin/products_controller.rb
class Admin::ProductsController < Admin::BaseController
  before_action :set_product, only: [:show, :edit, :update, :destroy, :toggle_active, :toggle_featured, :duplicate]
  
  def index
    authorize! :read, Product
    
    set_page_title("Products")
    add_breadcrumb("Products")
    
    @products = load_products
    @categories = Category.active.ordered
    @total_count = Product.count
    @active_count = Product.active.count
    @inactive_count = Product.where(active: false).count
  end
  
  def show
    authorize! :read, @product
    
    set_page_title(@product.name)
    add_breadcrumb("Products", admin_products_path)
    add_breadcrumb(@product.name)
    
    @variants = @product.product_variants.includes(images_attachments: :blob)
    @recent_orders = @product.order_items.includes(:order).recent.limit(10)
  end
  
  def new
    @product = Product.new
    authorize! :create, @product
    
    set_page_title("New Product")
    add_breadcrumb("Products", admin_products_path)
    add_breadcrumb("New Product")
    
    @categories = Category.active.ordered
  end
  
  def create
    @product = Product.new(product_params)
    authorize! :create, @product
    
    if @product.save
      redirect_to admin_product_path(@product), notice: 'Product was successfully created.'
    else
      @categories = Category.active.ordered
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    authorize! :update, @product
    
    set_page_title("Edit #{@product.name}")
    add_breadcrumb("Products", admin_products_path)
    add_breadcrumb(@product.name, admin_product_path(@product))
    add_breadcrumb("Edit")
    
    @categories = Category.active.ordered
  end
  
  def update
    authorize! :update, @product
    
    if @product.update(product_params)
      redirect_to admin_product_path(@product), notice: 'Product was successfully updated.'
    else
      @categories = Category.active.ordered
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    authorize! :destroy, @product
    
    @product.destroy
    redirect_to admin_products_path, notice: 'Product was successfully deleted.'
  end
  
  def toggle_active
    authorize! :update, @product
    
    @product.update(active: !@product.active)
    redirect_back(fallback_location: admin_products_path)
  end
  
  def toggle_featured
    authorize! :update, @product
    
    @product.update(featured: !@product.featured)
    redirect_back(fallback_location: admin_products_path)
  end
  
  def duplicate
    authorize! :create, Product
    
    new_product = @product.dup
    new_product.name = "#{@product.name} (Copy)"
    new_product.sku = nil # Will be auto-generated
    new_product.slug = nil # Will be auto-generated
    
    if new_product.save
      redirect_to edit_admin_product_path(new_product), notice: 'Product duplicated successfully.'
    else
      redirect_to admin_product_path(@product), alert: 'Failed to duplicate product.'
    end
  end
  
  def bulk_edit
    authorize! :update, Product
    
    @product_ids = params[:product_ids] || []
    @products = Product.where(id: @product_ids)
    
    set_page_title("Bulk Edit Products")
    add_breadcrumb("Products", admin_products_path)
    add_breadcrumb("Bulk Edit")
  end
  
  def bulk_update
    authorize! :update, Product
    
    product_ids = params[:product_ids] || []
    update_params = params[:bulk_update] || {}
    
    products = Product.where(id: product_ids)
    
    if update_params.present?
      products.update_all(update_params.permit(:active, :featured, :category_id))
      redirect_to admin_products_path, notice: "#{products.count} products updated successfully."
    else
      redirect_to admin_products_path, alert: 'No updates specified.'
    end
  end
  
  def bulk_destroy
    authorize! :destroy, Product
    
    product_ids = params[:product_ids] || []
    products = Product.where(id: product_ids)
    count = products.count
    
    products.destroy_all
    redirect_to admin_products_path, notice: "#{count} products deleted successfully."
  end
  
  def export
    authorize! :read, Product
    
    products = load_products(paginate: false)
    
    respond_to do |format|
      format.csv do
        send_data generate_csv(products), filename: "products-#{Date.current}.csv"
      end
    end
  end
  
  def import
    authorize! :create, Product
    
    # Implementation for CSV import
    # This would handle file upload and processing
  end
  
  private
  
  def set_product
    @product = Product.find(params[:id])
  end
  
  def product_params
    params.require(:product).permit(
      :name, :description, :price, :category_id, :active, :featured,
      :inventory_count, :weight, :dimensions, :materials, :care_instructions,
      images: []
    )
  end
  
  def load_products(paginate: true)
    products = Product.includes(:category, :product_variants, images_attachments: :blob)
    
    # Apply filters
    products = products.where(category: params[:category]) if params[:category].present?
    products = products.where(active: params[:active]) if params[:active].present?
    products = products.where('inventory_count <= ?', 5) if params[:filter] == 'low_stock'
    products = products.search(params[:search]) if params[:search].present?
    
    # Apply sorting
    case params[:sort]
    when 'name'
      products = products.order(:name)
    when 'price'
      products = products.order(:price)
    when 'created_at'
      products = products.order(created_at: :desc)
    else
      products = products.order(created_at: :desc)
    end
    
    paginate ? products.page(params[:page]).per(25) : products
  end
  
  def generate_csv(products)
    CSV.generate(headers: true) do |csv|
      csv << ['Name', 'SKU', 'Category', 'Price', 'Inventory', 'Active', 'Featured', 'Created At']
      
      products.each do |product|
        csv << [
          product.name,
          product.sku,
          product.category.name,
          product.price,
          product.inventory_count,
          product.active,
          product.featured,
          product.created_at.strftime('%Y-%m-%d')
        ]
      end
    end
  end
end
```

**2.1.2 Product Views**

```erb
<!-- app/views/admin/products/index.html.erb -->
<div class="space-y-6">
  <!-- Page Header -->
  <div class="flex items-center justify-between">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Products</h1>
      <p class="mt-1 text-sm text-gray-500">
        Manage your product catalog
      </p>
    </div>
    <div class="flex space-x-3">
      <%= link_to "Import Products", "#", 
          class: "inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 transition-colors" %>
      <%= link_to "Add Product", new_admin_product_path,
          class: "inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-pastel-pink hover:bg-opacity-90 transition-colors" %>
    </div>
  </div>
  
  <!-- Stats Cards -->
  <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
              <span class="text-white font-bold text-sm"><%= @total_count %></span>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Total Products</dt>
              <dd class="text-lg font-medium text-gray-900"><%= @total_count %></dd>
            </dl>
          </div>
        </div>
      </div>
    </div>
    
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-green-500 rounded-md flex items-center justify-center">
              <span class="text-white font-bold text-sm"><%= @active_count %></span>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Active Products</dt>
              <dd class="text-lg font-medium text-gray-900"><%= @active_count %></dd>
            </dl>
          </div>
        </div>
      </div>
    </div>
    
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-red-500 rounded-md flex items-center justify-center">
              <span class="text-white font-bold text-sm"><%= @inactive_count %></span>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Inactive Products</dt>
              <dd class="text-lg font-medium text-gray-900"><%= @inactive_count %></dd>
            </dl>
          </div>
        </div>
      </div>
    </div>
  </div>
  
  <!-- Filters and Search -->
  <div class="bg-white shadow rounded-lg">
    <div class="p-6">
      <%= form_with url: admin_products_path, method: :get, local: true, class: "space-y-4" do |f| %>
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
          <!-- Search -->
          <div>
            <%= f.text_field :search, 
                placeholder: "Search products...",
                value: params[:search],
                class: "block w-full border-gray-300 rounded-md shadow-sm focus:ring-pastel-pink focus:border-pastel-pink" %>
          </div>
          
          <!-- Category Filter -->
          <div>
            <%= f.select :category, 
                options_from_collection_for_select(@categories, :id, :name, params[:category]),
                { prompt: "All Categories" },
                { class: "block w-full border-gray-300 rounded-md shadow-sm focus:ring-pastel-pink focus:border-pastel-pink" } %>
          </div>
          
          <!-- Status Filter -->
          <div>
            <%= f.select :active, 
                options_for_select([['All Products', ''], ['Active', 'true'], ['Inactive', 'false']], params[:active]),
                {},
                { class: "block w-full border-gray-300 rounded-md shadow-sm focus:ring-pastel-pink focus:border-pastel-pink" } %>
          </div>
          
          <!-- Sort -->
          <div>
            <%= f.select :sort, 
                options_for_select([['Newest First', 'created_at'], ['Name A-Z', 'name'], ['Price Low-High', 'price']], params[:sort]),
                {},
                { class: "block w-full border-gray-300 rounded-md shadow-sm focus:ring-pastel-pink focus:border-pastel-pink" } %>
          </div>
        </div>
        
        <div class="flex justify-between items-center">
          <div class="flex space-x-2">
            <%= f.submit "Filter", class: "inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-pastel-pink hover:bg-opacity-90 transition-colors" %>
            <%= link_to "Clear", admin_products_path, class: "inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 transition-colors" %>
          </div>
          
          <div class="flex space-x-2">
            <%= link_to "Export CSV", admin_products_path(format: :csv, **request.query_parameters), 
                class: "inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 transition-colors" %>
          </div>
        </div>
      <% end %>
    </div>
  </div>
  
  <!-- Products Table -->
  <div class="bg-white shadow rounded-lg overflow-hidden">
    <div class="px-6 py-4 border-b border-gray-200">
      <div class="flex items-center justify-between">
        <h3 class="text-lg font-medium text-gray-900">Products</h3>
        <div class="flex items-center space-x-2">
          <button class="text-sm text-gray-500 hover:text-gray-700">
            Select All
          </button>
          <button class="text-sm text-gray-500 hover:text-gray-700">
            Bulk Actions
          </button>
        </div>
      </div>
    </div>
    
    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              <input type="checkbox" class="rounded border-gray-300">
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Product
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Category
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Price
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Inventory
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Status
            </th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
              Actions
            </th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <% @products.each do |product| %>
            <tr class="hover:bg-gray-50">
              <td class="px-6 py-4 whitespace-nowrap">
                <input type="checkbox" class="rounded border-gray-300" value="<%= product.id %>">
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex items-center">
                  <div class="flex-shrink-0 h-12 w-12">
                    <% if product.main_image %>
                      <%= image_tag product.main_image.variant(:thumbnail), 
                          class: "h-12 w-12 rounded-lg object-cover" %>
                    <% else %>
                      <div class="h-12 w-12 rounded-lg bg-gray-200 flex items-center justify-center">
                        <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                        </svg>
                      </div>
                    <% end %>
                  </div>
                  <div class="ml-4">
                    <div class="text-sm font-medium text-gray-900">
                      <%= link_to product.name, admin_product_path(product), class: "hover:text-pastel-pink" %>
                    </div>
                    <div class="text-sm text-gray-500"><%= product.sku %></div>
                  </div>
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                <%= product.category.name %>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                <%= product.display_price %>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium <%= stock_status_class(product) %>">
                  <%= product.inventory_count %>
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex items-center space-x-2">
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium <%= product.active? ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800' %>">
                    <%= product.active? ? 'Active' : 'Inactive' %>
                  </span>
                  <% if product.featured? %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                      Featured
                    </span>
                  <% end %>
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <div class="flex items-center justify-end space-x-2">
                  <%= link_to "View", admin_product_path(product), 
                      class: "text-pastel-pink hover:text-opacity-80" %>
                  <%= link_to "Edit", edit_admin_product_path(product), 
                      class: "text-gray-600 hover:text-gray-900" %>
                  <%= link_to "Delete", admin_product_path(product), 
                      method: :delete,
                      data: { confirm: "Are you sure?" },
                      class: "text-red-600 hover:text-red-900" %>
                </div>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    
    <!-- Pagination -->
    <div class="bg-white px-4 py-3 border-t border-gray-200 sm:px-6">
      <%= paginate @products if respond_to?(:paginate) %>
    </div>
  </div>
</div>

<!-- Helper method for stock status styling -->
<% content_for :head do %>
  <script>
    function stock_status_class(product) {
      if (product.out_of_stock()) {
        return 'bg-red-100 text-red-800';
      } else if (product.low_stock()) {
        return 'bg-yellow-100 text-yellow-800';
      } else {
        return 'bg-green-100 text-green-800';
      }
    }
  </script>
<% end %>
```

### Step 2.2: Create Product Form

**2.2.1 Product Form Partial**

```erb
<!-- app/views/admin/products/_form.html.erb -->
<%= form_with model: [:admin, @product], local: true, multipart: true, class: "space-y-6" do |f| %>
  <% if @product.errors.any? %>
    <div class="bg-red-50 border border-red-200 rounded-md p-4">
      <div class="flex">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
          </svg>
        </div>
        <div class="ml-3">
          <h3 class="text-sm font-medium text-red-800">
            There were <%= pluralize(@product.errors.count, "error") %> with your submission:
          </h3>
          <div class="mt-2 text-sm text-red-700">
            <ul class="list-disc pl-5 space-y-1">
              <% @product.errors.full_messages.each do |message| %>
                <li><%= message %></li>
              <% end %>
            </ul>
          </div>
        </div>