class CartsController < ApplicationController
  before_action :set_cart, only: [ :show, :clear ]
  before_action :ensure_cart_exists, only: [ :show ]

  def show
    @cart_items = @cart.cart_items.includes(:product, :product_variant)
  end

  def clear
    @cart.clear
    redirect_to cart_path, notice: "Your cart has been cleared."
  end

  private

  def set_cart
    @cart = current_cart
  end

  def ensure_cart_exists
    redirect_to root_path, alert: "Cart not found." unless @cart
  end

  def current_cart
    if user_signed_in?
      current_user.carts.find_or_create_by(user: current_user)
    else
      session_cart
    end
  end

  def session_cart
    session_id = session.id.to_s
    Cart.find_or_create_by(session_id: session_id)
  end
end
