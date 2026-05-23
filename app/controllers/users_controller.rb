class UsersController < ApplicationController
  before_action :set_user, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize User
    @pagy, @users = pagy(User.order(created_at: :desc), items: 20)
  end

  def show
    authorize @user
    # Shows user details
  end

  def new
    @user = User.new
    authorize @user
  end

  def create
    @user = User.new(user_params)
    authorize @user

    # Generate a temporary password if none provided
    if params[:user][:password].blank?
      temp_password = SecureRandom.alphanumeric(16)
      @user.password = temp_password
      @user.password_confirmation = temp_password
      @temporary_password = temp_password
    end

    if @user.save
      if @temporary_password
        flash[:success] = "User created successfully. Temporary password: #{@temporary_password}"
        flash[:notice] = "Please share this password securely with the user. It will not be shown again."
      else
        flash[:success] = "User created successfully."
      end
      redirect_to users_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @user
    # Renders edit form
  end

  def update
    authorize @user
    # Don't require password for updates unless it's being changed
    update_params = user_params

    if params[:user][:password].blank?
      update_params = update_params.except(:password, :password_confirmation)
    end

    if @user.update(update_params)
      flash[:success] = "User updated successfully."
      redirect_to users_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # The policy already checks if user can destroy (admin and not themselves)
    # But we still check here for a better error message
    if @user == current_user
      flash[:error] = "You cannot delete your own account."
      redirect_to users_path and return
    end

    authorize @user

    if @user.destroy
      flash[:success] = "User deleted successfully."
    else
      flash[:error] = "Failed to delete user."
    end

    redirect_to users_path
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :role, :password, :password_confirmation)
  end
end
