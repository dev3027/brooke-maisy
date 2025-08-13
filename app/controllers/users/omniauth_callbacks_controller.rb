class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: [ :google_oauth2, :facebook ]

  def google_oauth2
    handle_auth("Google")
  end

  def facebook
    handle_auth("Facebook")
  end

  def failure
    flash[:alert] = "There was an error authenticating with #{params[:strategy].humanize}. Please try again."
    redirect_to new_user_registration_url
  end

  private

  def handle_auth(kind)
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      flash[:notice] = I18n.t "devise.omniauth_callbacks.success", kind: kind
      sign_in_and_redirect @user, event: :authentication
    else
      session["devise.#{kind.downcase}_data"] = request.env["omniauth.auth"].except("extra")
      flash[:alert] = "There was an error creating your account. Please try again."
      redirect_to new_user_registration_url
    end
  end
end
