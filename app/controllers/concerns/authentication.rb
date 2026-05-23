module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :current_user, :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def authenticated?
    current_user.present?
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def authenticate(user)
    session[:user_id] = user.id
    @current_user = user
  end

  def unauthenticate
    session.delete(:user_id)
    @current_user = nil
  end

  def require_authentication
    authenticated? || redirect_to_sign_in
  end

  def redirect_to_sign_in
    redirect_to sign_in_path, alert: "You must be signed in to continue."
  end
end
