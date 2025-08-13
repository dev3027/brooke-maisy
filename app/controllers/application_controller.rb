class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Add admin helper method
  def admin_signed_in?
    user_signed_in? && current_user.admin?
  end

  helper_method :admin_signed_in?

  # Cart helper methods
  def current_cart
    @current_cart ||= find_or_create_cart
  end

  def cart_item_count
    current_cart&.total_items || 0
  end

  helper_method :current_cart, :cart_item_count

  protected

  # Helper method to set page title and meta description
  def set_page_meta(title: nil, description: nil)
    @page_title = title if title.present?
    @meta_description = description if description.present?
  end

  # Helper method to add breadcrumb items
  def add_breadcrumb(text, url = nil)
    @breadcrumbs ||= []
    @breadcrumbs << { text: text, url: url }
  end

  # Helper method to get breadcrumbs for views
  def breadcrumbs
    @breadcrumbs || []
  end
  helper_method :breadcrumbs

  private

  def find_or_create_cart
    if user_signed_in?
      # For logged-in users, find or create cart and merge any session cart
      user_cart = current_user.carts.find_or_create_by(user: current_user)

      # If there's a session cart, merge it with the user cart
      if session[:cart_id].present?
        session_cart = Cart.find_by(id: session[:cart_id], session_id: session.id.to_s)
        if session_cart && session_cart != user_cart
          user_cart.merge_with(session_cart)
          session.delete(:cart_id)
        end
      end

      user_cart
    else
      # For guest users, use session-based cart
      if session[:cart_id].present?
        cart = Cart.find_by(id: session[:cart_id], session_id: session.id.to_s)
        return cart if cart
      end

      # Create new session cart
      cart = Cart.create(session_id: session.id.to_s)
      session[:cart_id] = cart.id
      cart
    end
  end
end
