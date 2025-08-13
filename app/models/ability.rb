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
    can [ :bulk_edit, :bulk_update, :bulk_destroy, :export, :import ], Product
    can [ :toggle_active, :toggle_featured, :duplicate ], Product

    # Order management
    can :read, Order
    can :update, Order
    can [ :update_status, :update_payment_status, :send_tracking_email, :print_invoice ], Order

    # Customer management
    can :read, User
    can :update, User, role: "customer"

    # Review management
    can :manage, Review
    can [ :approve, :reject ], Review

    # Content management
    can :manage, Article

    # Admin user management
    can :read, User, role: "admin"
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
