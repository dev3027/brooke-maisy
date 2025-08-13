class ProductsController < ApplicationController
  before_action :set_product, only: [ :show ]

  def index
    @products = load_products
    @categories = Category.active.ordered
    @current_category = params[:category_id].present? ? Category.find(params[:category_id]) : nil
    @search_query = params[:search]
    @sort_option = params[:sort] || "newest"
    @price_range = params[:price_range]
    @availability = params[:availability]

    # For pagination (we'll implement basic pagination)
    @page = (params[:page] || 1).to_i
    @per_page = 12
    @total_count = @products.count
    @total_pages = (@total_count.to_f / @per_page).ceil

    # Apply pagination
    offset = (@page - 1) * @per_page
    @products = @products.limit(@per_page).offset(offset)

    # SEO
    set_meta_tags
  end

  def show
    # Ensure product is active for public viewing
    redirect_to products_path, alert: "Product not found" unless @product.active?

    @related_products = @product.category.products
                                .active
                                .where.not(id: @product.id)
                                .includes(:category, images_attachments: :blob)
                                .limit(4)

    @variants = @product.product_variants.active.includes(images_attachments: :blob)
    @reviews = @product.reviews.approved.includes(:user).order(created_at: :desc).limit(10)

    # SEO
    set_product_meta_tags
  end

  def search
    @search_query = params[:q]
    @products = load_products
    @categories = Category.active.ordered
    @sort_option = params[:sort] || "relevance"

    # For pagination
    @page = (params[:page] || 1).to_i
    @per_page = 12
    @total_count = @products.count
    @total_pages = (@total_count.to_f / @per_page).ceil

    # Apply pagination
    offset = (@page - 1) * @per_page
    @products = @products.limit(@per_page).offset(offset)

    render :index
  end

  private

  def set_product
    @product = Product.find_by!(slug: params[:id])
  end

  def load_products
    products = Product.active.includes(:category, :reviews, images_attachments: :blob)

    # Apply search
    if params[:search].present? || params[:q].present?
      query = params[:search] || params[:q]
      products = products.search(query)
    end

    # Apply category filter
    if params[:category_id].present?
      products = products.where(category_id: params[:category_id])
    end

    # Apply price range filter
    if params[:price_range].present?
      case params[:price_range]
      when "under_10"
        products = products.where("price < ?", 10)
      when "10_25"
        products = products.where("price >= ? AND price <= ?", 10, 25)
      when "25_50"
        products = products.where("price >= ? AND price <= ?", 25, 50)
      when "over_50"
        products = products.where("price > ?", 50)
      end
    end

    # Apply availability filter
    if params[:availability].present?
      case params[:availability]
      when "in_stock"
        products = products.in_stock
      when "out_of_stock"
        products = products.where(inventory_count: 0)
      end
    end

    # Apply sorting
    case params[:sort]
    when "name_asc"
      products = products.order(:name)
    when "name_desc"
      products = products.order(name: :desc)
    when "price_asc"
      products = products.order(:price)
    when "price_desc"
      products = products.order(price: :desc)
    when "oldest"
      products = products.order(:created_at)
    when "featured"
      products = products.order(featured: :desc, created_at: :desc)
    when "relevance"
      # For search results, keep default order
      products = products.order(created_at: :desc) unless params[:search].present? || params[:q].present?
    else # 'newest'
      products = products.order(created_at: :desc)
    end

    products
  end

  def set_meta_tags
    @page_title = if @current_category
                    "#{@current_category.name} - Brooke Maisy"
    elsif @search_query.present?
                    "Search: #{@search_query} - Brooke Maisy"
    else
                    "Shop All Products - Brooke Maisy"
    end

    @meta_description = if @current_category
                          "Browse our collection of handmade #{@current_category.name.downcase}. #{@current_category.description}"
    elsif @search_query.present?
                          "Search results for '#{@search_query}' - handmade crafts by Brooke Maisy"
    else
                          "Shop our complete collection of handmade bracelets, bookmarks, and stickers. Each piece crafted with love by Brooke Maisy."
    end
  end

  def set_product_meta_tags
    @page_title = "#{@product.name} - Brooke Maisy"
    @meta_description = @product.description.truncate(160)
    @canonical_url = product_url(@product)

    # Open Graph tags
    @og_title = @product.name
    @og_description = @product.description.truncate(200)
    @og_image = @product.main_image.present? ? url_for(@product.main_image) : nil
    @og_type = "product"

    # Product structured data
    @structured_data = {
      "@context" => "https://schema.org/",
      "@type" => "Product",
      "name" => @product.name,
      "description" => @product.description,
      "sku" => @product.sku,
      "category" => @product.category.name,
      "brand" => {
        "@type" => "Brand",
        "name" => "Brooke Maisy"
      },
      "offers" => {
        "@type" => "Offer",
        "price" => @product.price.to_f,
        "priceCurrency" => "USD",
        "availability" => @product.in_stock? ? "https://schema.org/InStock" : "https://schema.org/OutOfStock",
        "seller" => {
          "@type" => "Organization",
          "name" => "Brooke Maisy"
        }
      }
    }

    if @product.main_image.present?
      @structured_data["image"] = url_for(@product.main_image)
    end

    if @product.reviews.approved.any?
      @structured_data["aggregateRating"] = {
        "@type" => "AggregateRating",
        "ratingValue" => @product.average_rating,
        "reviewCount" => @product.reviews_count
      }
    end
  end
end
