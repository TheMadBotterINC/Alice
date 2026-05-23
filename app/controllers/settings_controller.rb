class SettingsController < ApplicationController
  def show
    @user = current_user
  end

  def update
    @user = current_user

    # Separate profile updates from password updates
    if updating_password?
      update_password
    else
      update_profile
    end
  end

  private

  def updating_password?
    params[:user][:current_password].present? ||
    params[:user][:password].present? ||
    params[:user][:password_confirmation].present?
  end

  def update_profile
    # Only allow updating name and email
    if @user.update(profile_params)
      flash[:success] = "Profile updated successfully."
      redirect_to settings_path
    else
      render :show, status: :unprocessable_entity
    end
  end

  def update_password
    # Verify current password first
    unless @user.authenticate(params[:user][:current_password])
      @user.errors.add(:current_password, "is incorrect")
      render :show, status: :unprocessable_entity
      return
    end

    # Update password
    if @user.update(password_params)
      flash[:success] = "Password changed successfully."
      redirect_to settings_path
    else
      render :show, status: :unprocessable_entity
    end
  end

  def profile_params
    params.require(:user).permit(:name, :email)
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
