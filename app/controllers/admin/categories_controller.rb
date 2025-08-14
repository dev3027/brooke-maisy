class Admin::CategoriesController < Admin::BaseController
  before_action :set_category, only: [ :show, :edit, :update, :destroy, :toggle_active, :move_up, :move_down ]

  def index
    authorize! :read, Category

    set_page_title("Categories")
    add_breadcrumb("Categories")

    @categories = Category.includes(:products).ordered
    @total_count = Category.count
    @active_count = Category.active.count
    @inactive_count = Category.where(active: false).count
  end

  def show
    authorize! :read, @category

    set_page_title(@category.name)
    add_breadcrumb("Categories", admin_categories_path)
    add_breadcrumb(@category.name)

    @products = @category.products.includes(:category, images_attachments: :blob)
                         .order(created_at: :desc)
                         .limit(20)
  end

  def new
    @category = Category.new
    authorize! :create, @category

    set_page_title("New Category")
    add_breadcrumb("Categories", admin_categories_path)
    add_breadcrumb("New Category")

    # Set default position
    @category.position = (Category.maximum(:position) || 0) + 1
  end

  def create
    @category = Category.new(category_params)
    authorize! :create, @category

    if @category.save
      redirect_to admin_categories_path, notice: "Category was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize! :update, @category

    set_page_title("Edit #{@category.name}")
    add_breadcrumb("Categories", admin_categories_path)
    add_breadcrumb(@category.name, admin_category_path(@category))
    add_breadcrumb("Edit")
  end

  def update
    authorize! :update, @category

    if @category.update(category_params)
      redirect_to admin_category_path(@category), notice: "Category was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! :destroy, @category

    if @category.products.any?
      redirect_to admin_categories_path, alert: "Cannot delete category with products. Please move or delete products first."
    else
      @category.destroy
      redirect_to admin_categories_path, notice: "Category was successfully deleted."
    end
  end

  def toggle_active
    authorize! :update, @category

    @category.update(active: !@category.active)
    redirect_back(fallback_location: admin_categories_path)
  end

  def move_up
    authorize! :update, @category

    # Find the category with the next lower position
    previous_category = Category.where("position < ?", @category.position)
                               .order(position: :desc)
                               .first

    if previous_category
      # Swap positions
      @category.transaction do
        temp_position = @category.position
        @category.update!(position: previous_category.position)
        previous_category.update!(position: temp_position)
      end
    end

    redirect_back(fallback_location: admin_categories_path)
  end

  def move_down
    authorize! :update, @category

    # Find the category with the next higher position
    next_category = Category.where("position > ?", @category.position)
                           .order(position: :asc)
                           .first

    if next_category
      # Swap positions
      @category.transaction do
        temp_position = @category.position
        @category.update!(position: next_category.position)
        next_category.update!(position: temp_position)
      end
    end

    redirect_back(fallback_location: admin_categories_path)
  end

  def reorder
    authorize! :update, Category

    category_ids = params[:category_ids] || []

    category_ids.each_with_index do |id, index|
      Category.where(id: id).update_all(position: index + 1)
    end

    render json: { status: "success" }
  end

  private

  def set_category
    @category = Category.find_by!(slug: params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :description, :active, :position)
  end
end
