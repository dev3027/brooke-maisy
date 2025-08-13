class Order < ApplicationRecord
  # Associations
  belongs_to :user, optional: true
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  # Enums
  enum :status, {
    pending: 0,
    processing: 1,
    shipped: 2,
    delivered: 3,
    cancelled: 4,
    refunded: 5
  }

  enum :payment_status, {
    payment_pending: 0,
    paid: 1,
    failed: 2,
    payment_refunded: 3,
    partially_refunded: 4
  }

  # Validations
  validates :order_number, presence: true, uniqueness: true
  validates :total_amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  validates :payment_status, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, :last_name, presence: true
  validates :address, :city, :state, :zip_code, :country, presence: true
  validates :session_id, presence: true, if: -> { user.blank? }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_payment_status, ->(payment_status) { where(payment_status: payment_status) }
  scope :completed, -> { where(status: [ :delivered ]) }
  scope :active, -> { where.not(status: [ :cancelled, :refunded ]) }

  # Callbacks
  before_validation :generate_order_number, if: -> { order_number.blank? }
  after_create :send_order_confirmation

  # Instance methods
  def to_param
    order_number
  end

  def subtotal
    order_items.sum { |item| item.total_price }
  end

  def tax_amount
    # Simple tax calculation - can be enhanced based on location
    subtotal * 0.08
  end

  def shipping_cost
    # Simple shipping calculation - can be enhanced based on weight/location
    return 0 if subtotal >= 50 # Free shipping over $50
    5.99
  end

  def calculate_total
    subtotal + tax_amount + shipping_cost
  end

  def items_count
    order_items.sum(:quantity)
  end

  def can_be_cancelled?
    pending? || processing?
  end

  def can_be_refunded?
    delivered? && created_at > 30.days.ago
  end

  def formatted_total
    "$#{total_amount.to_f}"
  end

  def formatted_subtotal
    "$#{subtotal.to_f}"
  end

  def formatted_tax
    "$#{tax_amount.to_f}"
  end

  def formatted_shipping
    "$#{shipping_cost.to_f}"
  end

  def shipping_address_formatted
    return nil if shipping_address.blank?
    shipping_address.gsub(/\n/, "<br>").html_safe
  end

  def billing_address_formatted
    return nil if billing_address.blank?
    billing_address.gsub(/\n/, "<br>").html_safe
  end

  def status_color
    case status
    when "pending" then "yellow"
    when "processing" then "blue"
    when "shipped" then "purple"
    when "delivered" then "green"
    when "cancelled" then "red"
    when "refunded" then "gray"
    else "gray"
    end
  end

  def payment_status_color
    case payment_status
    when "payment_pending" then "yellow"
    when "paid" then "green"
    when "failed" then "red"
    when "payment_refunded" then "gray"
    when "partially_refunded" then "orange"
    else "gray"
    end
  end

  def build_from_cart(cart)
    return if cart.empty?

    cart.cart_items.each do |cart_item|
      order_items.build(
        product: cart_item.product,
        product_variant: cart_item.product_variant,
        quantity: cart_item.quantity,
        unit_price: cart_item.item_price,
        total_price: cart_item.total_price
      )
    end

    self.total_amount = calculate_total
  end

  def customer_name
    if user.present?
      user.full_name
    else
      "#{first_name} #{last_name}".strip
    end
  end

  def customer_email
    user&.email || email
  end

  private

  def generate_order_number
    loop do
      self.order_number = "BM#{Date.current.strftime('%Y%m%d')}#{SecureRandom.hex(4).upcase}"
      break unless Order.exists?(order_number: order_number)
    end
  end

  def send_order_confirmation
    # OrderMailer.confirmation(self).deliver_later
    # TODO: Implement order confirmation email
  end
end
