import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="image-gallery"
export default class extends Controller {
  static targets = ["image", "lightbox", "lightboxImage"]

  connect() {
    this.currentIndex = 0
    this.bindKeyboardEvents()
  }

  disconnect() {
    this.unbindKeyboardEvents()
  }

  selectImage(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this.showImage(index)
    this.updateThumbnails(index)
  }

  showImage(index) {
    // Hide all images
    this.imageTargets.forEach(img => img.classList.add('hidden'))
    
    // Show selected image
    if (this.imageTargets[index]) {
      this.imageTargets[index].classList.remove('hidden')
      this.currentIndex = index
    }
  }

  updateThumbnails(activeIndex) {
    // Update thumbnail borders
    const thumbnails = this.element.querySelectorAll('[data-index]')
    thumbnails.forEach((thumb, index) => {
      if (index === activeIndex) {
        thumb.classList.remove('border-transparent', 'hover:border-ivory-300')
        thumb.classList.add('border-ivory-500')
      } else {
        thumb.classList.remove('border-ivory-500')
        thumb.classList.add('border-transparent', 'hover:border-ivory-300')
      }
    })
  }

  openLightbox(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this.currentIndex = index
    
    // Set lightbox image
    const currentImage = this.imageTargets[index]
    if (currentImage && this.hasLightboxImageTarget) {
      this.lightboxImageTarget.src = currentImage.src
      this.lightboxImageTarget.alt = currentImage.alt
    }
    
    // Show lightbox
    if (this.hasLightboxTarget) {
      this.lightboxTarget.classList.remove('hidden')
      document.body.style.overflow = 'hidden'
    }
  }

  closeLightbox() {
    if (this.hasLightboxTarget) {
      this.lightboxTarget.classList.add('hidden')
      document.body.style.overflow = 'auto'
    }
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  nextImage() {
    if (this.currentIndex < this.imageTargets.length - 1) {
      this.currentIndex++
      this.updateLightboxImage()
    }
  }

  previousImage() {
    if (this.currentIndex > 0) {
      this.currentIndex--
      this.updateLightboxImage()
    }
  }

  updateLightboxImage() {
    const currentImage = this.imageTargets[this.currentIndex]
    if (currentImage && this.hasLightboxImageTarget) {
      this.lightboxImageTarget.src = currentImage.src
      this.lightboxImageTarget.alt = currentImage.alt
    }
  }

  bindKeyboardEvents() {
    this.keyboardHandler = this.handleKeyboard.bind(this)
    document.addEventListener('keydown', this.keyboardHandler)
  }

  unbindKeyboardEvents() {
    if (this.keyboardHandler) {
      document.removeEventListener('keydown', this.keyboardHandler)
    }
  }

  handleKeyboard(event) {
    // Only handle keyboard events when lightbox is open
    if (this.hasLightboxTarget && !this.lightboxTarget.classList.contains('hidden')) {
      switch (event.key) {
        case 'Escape':
          this.closeLightbox()
          break
        case 'ArrowLeft':
          event.preventDefault()
          this.previousImage()
          break
        case 'ArrowRight':
          event.preventDefault()
          this.nextImage()
          break
      }
    }
  }
}