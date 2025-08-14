class Admin::ProductsController < Admin::BaseController
  before_action :set_product, only: [ :show, :edit, :update, :destroy, :toggle_active, :toggle_featured, :duplicate ]

  def index
    authorize! :read, Product

    set_page_title("Products")
    add_breadcrumb("Products")

    @products = load_products
    @categories = Category.active.ordered
    @total_count = Product.count
    @active_count = Product.where(active: true).count
    @inactive_count = Product.where(active: false).count
  end

  def show
    authorize! :read, @product

    set_page_title(@product.name)
    add_breadcrumb("Products", admin_products_path)
    add_breadcrumb(@product.name)

    @variants = @product.product_variants.includes(images_attachments: :blob)
    @recent_orders = @product.order_items.includes(:order).order(created_at: :desc).limit(10)
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
      redirect_to admin_product_path(@product), notice: "Product was successfully created."
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
      redirect_to admin_product_path(@product), notice: "Product was successfully updated."
    else
      @categories = Category.active.ordered
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! :destroy, @product

    @product.destroy
    redirect_to admin_products_path, notice: "Product was successfully deleted."
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
      redirect_to edit_admin_product_path(new_product), notice: "Product duplicated successfully."
    else
      redirect_to admin_product_path(@product), alert: "Failed to duplicate product."
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
      redirect_to admin_products_path, alert: "No updates specified."
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
    redirect_to admin_products_path, notice: "Import functionality coming soon."
  end

  private

  def set_product
    @product = Product.find_by!(slug: params[:id])
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
    products = products.where("inventory_count <= ?", 5) if params[:filter] == "low_stock"
    products = products.search(params[:search]) if params[:search].present?

    # Apply sorting
    case params[:sort]
    when "name"
      products = products.order(:name)
    when "price"
      products = products.order(:price)
    when "created_at"
      products = products.order(created_at: :desc)
    else
      products = products.order(created_at: :desc)
    end

    # For now, we'll use basic pagination with limit/offset until we add Kaminari
    if paginate
      page = (params[:page] || 1).to_i
      per_page = 25
      offset = (page - 1) * per_page
      products.limit(per_page).offset(offset)
    else
      products
    end
  end

  def generate_csv(products)
    require "csv"

    CSV.generate(headers: true) do |csv|
      csv << [ "Name", "SKU", "Category", "Price", "Inventory", "Active", "Featured", "Created At" ]

      products.each do |product|
        csv << [
          product.name,
          product.sku,
          product.category.name,
          product.price,
          product.inventory_count,
          product.active,
          product.featured,
          product.created_at.strftime("%Y-%m-%d")
        ]
      end
    end
  end
end
