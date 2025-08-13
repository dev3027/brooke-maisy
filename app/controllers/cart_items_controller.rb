class CartItemsController < ApplicationController
  before_action :set_cart
  before_action :set_cart_item, only: [ :update, :destroy ]
  before_action :set_product, only: [ :create ]

  def create
    @product_variant = @product.product_variants.find(params[:product_variant_id]) if params[:product_variant_id].present?
    quantity = params[:quantity].to_i.positive? ? params[:quantity].to_i : 1

    # Check inventory
    available_quantity = @product_variant&.inventory_count || @product.inventory_count
    if quantity > available_quantity
      respond_to do |format|
        format.html { redirect_back(fallback_location: @product, alert: "Not enough items in stock.") }
        format.json { render json: { error: "Not enough items in stock." }, status: :unprocessable_entity }
      end
      return
    end

    @cart_item = @cart.add_item(@product, @product_variant, quantity)

    if @cart_item.persisted?
      respond_to do |format|
        format.html { redirect_back(fallback_location: cart_path, notice: "Item added to cart successfully.") }
        format.json { render json: cart_data, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_back(fallback_location: @product, alert: "Unable to add item to cart.") }
        format.json { render json: { errors: @cart_item.errors }, status: :unprocessable_entity }
      end
    end
  end

  def update
    quantity = params[:quantity].to_i

    if quantity <= 0
      @cart_item.destroy
      message = "Item removed from cart."
    else
      # Check inventory
      available_quantity = @cart_item.product_variant&.inventory_count || @cart_item.product.inventory_count
      if quantity > available_quantity
        respond_to do |format|
          format.html { redirect_to cart_path, alert: "Not enough items in stock." }
          format.json { render json: { error: "Not enough items in stock." }, status: :unprocessable_entity }
        end
        return
      end

      @cart_item.update(quantity: quantity)
      message = "Cart updated successfully."
    end

    respond_to do |format|
      format.html { redirect_to cart_path, notice: message }
      format.json { render json: cart_data }
    end
  end

  def destroy
    @cart_item.destroy
    respond_to do |format|
      format.html { redirect_to cart_path, notice: "Item removed from cart." }
      format.json { render json: cart_data }
    end
  end

  private

  def set_cart
    @cart = current_cart
  end

  def set_cart_item
    @cart_item = @cart.cart_items.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to cart_path, alert: "Cart item not found." }
      format.json { render json: { error: "Cart item not found." }, status: :not_found }
    end
  end

  def set_product
    @product = Product.active.find_by(slug: params[:product_id]) || Product.active.find(params[:product_id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to products_path, alert: "Product not found." }
      format.json { render json: { error: "Product not found." }, status: :not_found }
    end
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

  def cart_data
    {
      cart: {
        total_items: @cart.total_items,
        total_price: @cart.total_price,
        formatted_total: @cart.formatted_total,
        items: @cart.cart_items.includes(:product, :product_variant).map do |item|
          {
            id: item.id,
            name: item.item_name,
            price: item.item_price,
            quantity: item.quantity,
            total_price: item.total_price,
            formatted_total_price: item.formatted_total_price,
            max_quantity: item.max_quantity,
            in_stock: item.in_stock?
          }
        end
      }
    }
  end
end
