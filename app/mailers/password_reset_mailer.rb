class PasswordResetMailer < ApplicationMailer
  def reset_email(user)
    @user = user
    @reset_url = edit_password_reset_url(@user.reset_password_token)

    mail(
      to: @user.email,
      subject: "Reset your Alice password"
    )
  end
end
