class PasswordResetsController < ApplicationController
  skip_before_action :require_authentication
  before_action :find_user_by_token, only: [ :edit, :update ]
  before_action :check_token_expiration, only: [ :edit, :update ]

  # GET /password_resets/new
  def new
  end

  # POST /password_resets
  def create
    @user = User.find_by(email: params[:email].to_s.downcase.strip)

    if @user
      @user.generate_password_reset_token
      PasswordResetMailer.reset_email(@user).deliver_later
    end

    # Always show success message (security: don't reveal if email exists)
    flash[:notice] = "If that email address is in our system, we've sent password reset instructions."
    redirect_to sign_in_path
  end

  # GET /password_resets/:token/edit
  def edit
  end

  # PATCH/PUT /password_resets/:token
  def update
    if params[:password].blank?
      flash.now[:alert] = "Password can't be blank"
      render :edit, status: :unprocessable_entity
    elsif @user.update(password: params[:password], password_confirmation: params[:password_confirmation])
      @user.clear_password_reset
      flash[:notice] = "Your password has been reset successfully. Please sign in."
      redirect_to sign_in_path
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def find_user_by_token
    @user = User.find_by(reset_password_token: params[:token])

    unless @user
      flash[:alert] = "Invalid or expired password reset link"
      redirect_to sign_in_path
    end
  end

  def check_token_expiration
    if @user&.password_reset_expired?
      flash[:alert] = "Password reset link has expired. Please request a new one."
      redirect_to new_password_reset_path
    end
  end
end
