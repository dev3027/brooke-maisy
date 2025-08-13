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
      active_products: Product.where(active: true).count,
      total_orders: Order.count,
      pending_orders: Order.where(status: "pending").count,
      total_customers: User.where(role: "customer").count,
      total_revenue: Order.where(status: "completed").sum(:total_amount) || 0,
      pending_reviews: Review.where(approved: false).count
    }
  end

  def load_recent_orders
    Order.includes(:user, :order_items)
         .order(created_at: :desc)
         .limit(10)
  end

  def load_low_stock_products
    Product.where(active: true)
           .where("inventory_count <= ?", 5)
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
