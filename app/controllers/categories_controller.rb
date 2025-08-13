class CategoriesController < ApplicationController
  before_action :set_category, only: [ :show ]

  def index
    @categories = Category.active.ordered.includes(:products)
    @featured_products = Product.active.featured.includes(:category, images_attachments: :blob).limit(8)

    # SEO
    @page_title = "Shop by Category - Brooke Maisy"
    @meta_description = "Browse our handmade crafts by category. Find the perfect bracelets, bookmarks, and stickers crafted with love by Brooke Maisy."
  end

  def show
    # Ensure category is active for public viewing
    redirect_to categories_path, alert: "Category not found" unless @category.active?

    @products = load_category_products
    @sort_option = params[:sort] || "newest"
    @price_range = params[:price_range]
    @availability = params[:availability]

    # For pagination
    @page = (params[:page] || 1).to_i
    @per_page = 12
    @total_count = @products.count
    @total_pages = (@total_count.to_f / @per_page).ceil

    # Apply pagination
    offset = (@page - 1) * @per_page
    @products = @products.limit(@per_page).offset(offset)

    # Related categories (other active categories)
    @related_categories = Category.active.where.not(id: @category.id).ordered.limit(3)

    # SEO
    set_category_meta_tags
  end

  private

  def set_category
    @category = Category.find_by!(slug: params[:id])
  end

  def load_category_products
    products = @category.products.active.includes(:category, :reviews, images_attachments: :blob)

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
    else # 'newest'
      products = products.order(created_at: :desc)
    end

    products
  end

  def set_category_meta_tags
    @page_title = "#{@category.name} - Brooke Maisy"
    @meta_description = @category.description.present? ?
                        "#{@category.description} Browse our handmade #{@category.name.downcase} collection." :
                        "Browse our handmade #{@category.name.downcase} collection. Each piece crafted with love by Brooke Maisy."

    @canonical_url = category_url(@category)

    # Open Graph tags
    @og_title = "#{@category.name} - Handmade Crafts"
    @og_description = @meta_description
    @og_type = "website"

    # Category structured data
    @structured_data = {
      "@context" => "https://schema.org/",
      "@type" => "CollectionPage",
      "name" => @category.name,
      "description" => @category.description,
      "url" => category_url(@category),
      "mainEntity" => {
        "@type" => "ItemList",
        "numberOfItems" => @category.products.active.count,
        "itemListElement" => @category.products.active.limit(10).map.with_index do |product, index|
          {
            "@type" => "ListItem",
            "position" => index + 1,
            "item" => {
              "@type" => "Product",
              "name" => product.name,
              "url" => product_url(product)
            }
          }
        end
      }
    }
  end
end
