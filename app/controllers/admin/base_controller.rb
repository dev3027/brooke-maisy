class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :set_admin_context

  layout "admin/application"

  # Add CanCanCan integration
  check_authorization unless: :devise_controller?

  rescue_from CanCan::AccessDenied do |exception|
    respond_to do |format|
      format.html { redirect_to admin_root_path, alert: exception.message }
      format.json { render json: { error: exception.message }, status: :forbidden }
    end
  end

  protected

  def ensure_admin!
    authorize! :access, :admin_panel
  end

  def set_admin_context
    @admin_context = true
    @page_title = controller_name.humanize
    @breadcrumbs = []
  end

  def set_page_title(title)
    @page_title = title
  end

  def add_breadcrumb(name, path = nil)
    @breadcrumbs << { name: name, path: path }
  end

  def handle_admin_error(exception)
    Rails.logger.error "Admin Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    respond_to do |format|
      format.html { redirect_to admin_root_path, alert: "An error occurred. Please try again." }
      format.json { render json: { error: "An error occurred" }, status: :unprocessable_entity }
    end
  end

  private

  def admin_params_filter(params, allowed_keys)
    params.require(:admin).permit(allowed_keys)
  rescue ActionController::ParameterMissing
    {}
  end
end
