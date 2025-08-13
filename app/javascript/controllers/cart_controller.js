import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["quantity", "total", "itemCount"]
  static values = { itemId: Number }

  connect() {
    console.log("Cart controller connected")
    this.updateQuantityLimits()
  }

  updateVariantSelection(event) {
    const selectedVariant = event.target
    const price = selectedVariant.dataset.price
    const stock = parseInt(selectedVariant.dataset.stock)
    const inStock = selectedVariant.dataset.inStock === 'true'
    
    // Update quantity limits based on selected variant
    const quantityInput = this.element.querySelector('input[name="quantity"]')
    if (quantityInput) {
      quantityInput.max = Math.min(stock, 10)
      if (parseInt(quantityInput.value) > stock) {
        quantityInput.value = Math.min(stock, 1)
      }
    }
    
    // Update add to cart button state
    const addToCartButton = this.element.querySelector('button[type="submit"]')
    if (addToCartButton) {
      addToCartButton.disabled = !inStock
      addToCartButton.textContent = inStock ? 'Add to Cart' : 'Out of Stock'
    }
  }

  validateQuantity(event) {
    const input = event.target
    const max = parseInt(input.max)
    const min = parseInt(input.min)
    let value = parseInt(input.value)
    
    if (value > max) {
      input.value = max
    } else if (value < min) {
      input.value = min
    }
  }

  updateQuantityLimits() {
    // Set initial quantity limits based on product or selected variant
    const quantityInput = this.element.querySelector('input[name="quantity"]')
    const selectedVariant = this.element.querySelector('input[name="product_variant_id"]:checked')
    
    if (quantityInput && selectedVariant) {
      const stock = parseInt(selectedVariant.dataset.stock)
      quantityInput.max = Math.min(stock, 10)
    }
  }

  increaseQuantity(event) {
    event.preventDefault()
    const itemId = event.currentTarget.dataset.cartItemId
    const quantityInput = document.querySelector(`input[data-cart-item-id="${itemId}"]`)
    const currentQuantity = parseInt(quantityInput.value)
    const maxQuantity = parseInt(quantityInput.max)
    
    if (currentQuantity < maxQuantity) {
      quantityInput.value = currentQuantity + 1
      this.updateQuantity(event)
    }
  }

  decreaseQuantity(event) {
    event.preventDefault()
    const itemId = event.currentTarget.dataset.cartItemId
    const quantityInput = document.querySelector(`input[data-cart-item-id="${itemId}"]`)
    const currentQuantity = parseInt(quantityInput.value)
    
    if (currentQuantity > 1) {
      quantityInput.value = currentQuantity - 1
      this.updateQuantity(event)
    } else {
      // If quantity would be 0, remove the item
      this.removeItem(itemId)
    }
  }

  updateQuantity(event) {
    const itemId = event.currentTarget.dataset.cartItemId || event.target.dataset.cartItemId
    const quantity = event.target.value || document.querySelector(`input[data-cart-item-id="${itemId}"]`).value
    
    if (quantity <= 0) {
      this.removeItem(itemId)
      return
    }

    this.showLoading(itemId)

    fetch(`/cart_items/${itemId}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Accept': 'application/json'
      },
      body: JSON.stringify({
        quantity: quantity
      })
    })
    .then(response => response.json())
    .then(data => {
      if (data.error) {
        this.showError(data.error)
        // Reset quantity to previous value
        const quantityInput = document.querySelector(`input[data-cart-item-id="${itemId}"]`)
        quantityInput.value = quantityInput.dataset.previousValue || 1
      } else {
        this.updateCartDisplay(data.cart)
        this.showSuccess('Cart updated successfully')
      }
    })
    .catch(error => {
      console.error('Error updating cart:', error)
      this.showError('Failed to update cart')
    })
    .finally(() => {
      this.hideLoading(itemId)
    })
  }

  removeItem(itemId) {
    if (!confirm('Are you sure you want to remove this item?')) {
      return
    }

    this.showLoading(itemId)

    fetch(`/cart_items/${itemId}`, {
      method: 'DELETE',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Accept': 'application/json'
      }
    })
    .then(response => response.json())
    .then(data => {
      // Remove the item from the DOM
      const itemElement = document.querySelector(`[data-cart-item-id="${itemId}"]`)
      if (itemElement) {
        itemElement.remove()
      }
      
      this.updateCartDisplay(data.cart)
      this.showSuccess('Item removed from cart')
      
      // If cart is empty, reload the page to show empty state
      if (data.cart.total_items === 0) {
        window.location.reload()
      }
    })
    .catch(error => {
      console.error('Error removing item:', error)
      this.showError('Failed to remove item')
    })
    .finally(() => {
      this.hideLoading(itemId)
    })
  }

  addToCart(event) {
    event.preventDefault()
    const form = event.target.closest('form')
    const formData = new FormData(form)
    
    this.showAddToCartLoading(event.target)

    fetch(form.action, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Accept': 'application/json'
      },
      body: formData
    })
    .then(response => response.json())
    .then(data => {
      if (data.error) {
        this.showError(data.error)
      } else {
        this.updateCartDisplay(data.cart)
        this.showSuccess('Item added to cart')
        this.showCartPreview(data.cart)
      }
    })
    .catch(error => {
      console.error('Error adding to cart:', error)
      this.showError('Failed to add item to cart')
    })
    .finally(() => {
      this.hideAddToCartLoading(event.target)
    })
  }

  updateCartDisplay(cart) {
    // Update cart item count in navigation
    const cartCountElements = document.querySelectorAll('[data-cart-count]')
    cartCountElements.forEach(element => {
      element.textContent = cart.total_items
      element.style.display = cart.total_items > 0 ? 'inline' : 'none'
    })

    // Update cart total
    const cartTotalElements = document.querySelectorAll('[data-cart-total]')
    cartTotalElements.forEach(element => {
      element.textContent = cart.formatted_total
    })

    // Update individual item totals
    cart.items.forEach(item => {
      const itemTotalElement = document.querySelector(`[data-item-total="${item.id}"]`)
      if (itemTotalElement) {
        itemTotalElement.textContent = item.formatted_total_price
      }
    })
  }

  showCartPreview(cart) {
    // Create and show a cart preview modal or dropdown
    // This could be enhanced with a more sophisticated preview
    const preview = document.createElement('div')
    preview.className = 'fixed top-4 right-4 bg-white border border-gray-200 rounded-lg shadow-lg p-4 z-50'
    preview.innerHTML = `
      <div class="flex items-center">
        <svg class="w-5 h-5 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
        </svg>
        <span class="text-sm font-medium">Added to cart!</span>
      </div>
      <div class="mt-2 text-sm text-gray-600">
        ${cart.total_items} items • ${cart.formatted_total}
      </div>
    `
    
    document.body.appendChild(preview)
    
    setTimeout(() => {
      preview.remove()
    }, 3000)
  }

  showLoading(itemId) {
    const itemElement = document.querySelector(`[data-cart-item-id="${itemId}"]`)
    if (itemElement) {
      itemElement.style.opacity = '0.5'
      itemElement.style.pointerEvents = 'none'
    }
  }

  hideLoading(itemId) {
    const itemElement = document.querySelector(`[data-cart-item-id="${itemId}"]`)
    if (itemElement) {
      itemElement.style.opacity = '1'
      itemElement.style.pointerEvents = 'auto'
    }
  }

  showAddToCartLoading(button) {
    button.disabled = true
    button.innerHTML = `
      <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      Adding...
    `
  }

  hideAddToCartLoading(button) {
    button.disabled = false
    button.innerHTML = 'Add to Cart'
  }

  showSuccess(message) {
    this.showNotification(message, 'success')
  }

  showError(message) {
    this.showNotification(message, 'error')
  }

  showNotification(message, type) {
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 p-4 rounded-lg shadow-lg z-50 ${
      type === 'success' ? 'bg-green-100 text-green-800 border border-green-200' : 'bg-red-100 text-red-800 border border-red-200'
    }`
    notification.textContent = message
    
    document.body.appendChild(notification)
    
    setTimeout(() => {
      notification.remove()
    }, 3000)
  }
}