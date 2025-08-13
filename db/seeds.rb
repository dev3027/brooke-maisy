# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create admin user
admin_user = User.find_or_create_by!(email: 'admin@brookemaisy.com') do |user|
  user.password = 'password123'
  user.password_confirmation = 'password123'
  user.first_name = 'Admin'
  user.last_name = 'User'
  user.role = 'admin'
end

puts "Created admin user: #{admin_user.email}"

# Create categories
categories_data = [
  { name: 'Handmade Crafts', description: 'Beautiful handcrafted items made with love', position: 1 },
  { name: 'Jewelry', description: 'Unique jewelry pieces and accessories', position: 2 },
  { name: 'Home Decor', description: 'Decorative items for your home', position: 3 },
  { name: 'Textiles', description: 'Handwoven textiles and fabrics', position: 4 },
  { name: 'Art Prints', description: 'Original art prints and illustrations', position: 5 }
]

categories = []
categories_data.each do |cat_data|
  category = Category.find_or_create_by!(name: cat_data[:name]) do |cat|
    cat.description = cat_data[:description]
    cat.position = cat_data[:position]
    cat.active = true
  end
  categories << category
  puts "Created category: #{category.name}"
end

# Create sample products
products_data = [
  {
    name: 'Handwoven Scarf',
    description: 'Beautiful handwoven scarf made from organic cotton. Perfect for any season.',
    price: 45.00,
    inventory_count: 12,
    category: categories[3], # Textiles
    active: true,
    featured: true,
    materials: 'Organic Cotton',
    care_instructions: 'Hand wash cold, lay flat to dry'
  },
  {
    name: 'Silver Moon Necklace',
    description: 'Elegant silver necklace with moon pendant. Handcrafted with sterling silver.',
    price: 78.00,
    inventory_count: 8,
    category: categories[1], # Jewelry
    active: true,
    featured: true,
    materials: 'Sterling Silver',
    weight: 0.5
  },
  {
    name: 'Ceramic Vase',
    description: 'Hand-thrown ceramic vase with unique glaze. Perfect for fresh or dried flowers.',
    price: 32.00,
    inventory_count: 15,
    category: categories[2], # Home Decor
    active: true,
    featured: false,
    materials: 'Ceramic',
    dimensions: '8" H x 4" W'
  },
  {
    name: 'Macrame Wall Hanging',
    description: 'Intricate macrame wall hanging made with natural cotton rope.',
    price: 55.00,
    inventory_count: 6,
    category: categories[0], # Handmade Crafts
    active: true,
    featured: true,
    materials: 'Cotton Rope',
    dimensions: '24" H x 18" W'
  },
  {
    name: 'Botanical Print Set',
    description: 'Set of 3 botanical prints. High-quality prints on archival paper.',
    price: 25.00,
    inventory_count: 20,
    category: categories[4], # Art Prints
    active: true,
    featured: false,
    materials: 'Archival Paper',
    dimensions: '8" x 10" each'
  },
  {
    name: 'Leather Bracelet',
    description: 'Handcrafted leather bracelet with brass accents.',
    price: 28.00,
    inventory_count: 3, # Low stock
    category: categories[1], # Jewelry
    active: true,
    featured: false,
    materials: 'Leather, Brass'
  },
  {
    name: 'Woven Basket',
    description: 'Traditional woven basket perfect for storage or decoration.',
    price: 42.00,
    inventory_count: 0, # Out of stock
    category: categories[0], # Handmade Crafts
    active: false,
    featured: false,
    materials: 'Natural Fibers',
    dimensions: '12" H x 10" W'
  }
]

products_data.each do |product_data|
  product = Product.find_or_create_by!(name: product_data[:name]) do |prod|
    prod.description = product_data[:description]
    prod.price = product_data[:price]
    prod.inventory_count = product_data[:inventory_count]
    prod.category = product_data[:category]
    prod.active = product_data[:active]
    prod.featured = product_data[:featured]
    prod.materials = product_data[:materials]
    prod.care_instructions = product_data[:care_instructions]
    prod.weight = product_data[:weight]
    prod.dimensions = product_data[:dimensions]
  end
  puts "Created product: #{product.name} (#{product.category.name})"
end

puts "\nSeed data created successfully!"
puts "Admin login: admin@brookemaisy.com / password123"
puts "Categories: #{Category.count}"
puts "Products: #{Product.count}"
puts "- Active products: #{Product.where(active: true).count}"
puts "- Featured products: #{Product.where(featured: true).count}"
puts "- Low stock products: #{Product.where('inventory_count <= 5').count}"
puts "- Out of stock products: #{Product.where(inventory_count: 0).count}"
