class SessionsController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create ]

  def new
    # Redirect if already signed in
    redirect_to root_path if authenticated?
  end

  def create
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password])
      authenticate(user)
      redirect_to root_path, notice: "Signed in successfully."
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    unauthenticate
    redirect_to sign_in_path, notice: "Signed out successfully."
  end
end
