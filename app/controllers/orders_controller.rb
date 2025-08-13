class OrdersController < ApplicationController
  before_action :authenticate_user!, except: [ :guest_checkout ]
  before_action :set_cart, only: [ :new, :create, :guest_checkout ]
  before_action :ensure_cart_has_items, only: [ :new, :create, :guest_checkout ]

  def index
    @orders = current_user.orders.includes(:order_items).order(created_at: :desc)
  end

  def show
    @order = current_user.orders.find(params[:id])
  end

  def new
    @order = Order.new
    @order.build_from_cart(@cart)

    # Pre-fill user information if logged in
    if user_signed_in?
      @order.user = current_user
      @order.email = current_user.email
      @order.first_name = current_user.first_name
      @order.last_name = current_user.last_name
      @order.phone = current_user.phone
      @order.address = current_user.address
      @order.city = current_user.city
      @order.state = current_user.state
      @order.zip_code = current_user.zip_code
      @order.country = current_user.country
    end
  end

  def create
    @order = Order.new(order_params)
    @order.user = current_user if user_signed_in?
    @order.session_id = session.id.to_s unless user_signed_in?

    # Build order items from cart
    @order.build_from_cart(@cart)

    if @order.save
      # Clear the cart after successful order creation
      @cart.clear
      session.delete(:cart_id) unless user_signed_in?

      redirect_to order_path(@order), notice: "Your order has been created successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def guest_checkout
    # Allow guest users to create orders
    @order = Order.new
    @order.build_from_cart(@cart)
    render :new
  end

  private

  def set_cart
    @cart = current_cart
  end

  def ensure_cart_has_items
    if @cart.empty?
      redirect_to cart_path, alert: "Your cart is empty. Please add some items before checkout."
    end
  end

  def order_params
    params.require(:order).permit(
      :email, :first_name, :last_name, :phone,
      :address, :city, :state, :zip_code, :country,
      :notes, :shipping_method, :payment_method
    )
  end
end
