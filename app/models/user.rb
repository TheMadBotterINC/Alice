class User < ApplicationRecord
  has_secure_password

  # Role-based access control (simplified to 2 roles)
  enum :role, {
    admin: 0,
    viewer: 1
  }, default: :viewer

  # Validations
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  # Normalize email to lowercase
  before_validation :normalize_email

  # Password reset methods
  def generate_password_reset_token
    self.reset_password_token = SecureRandom.urlsafe_base64
    self.reset_password_sent_at = Time.current
    save(validate: false)
  end

  def password_reset_expired?
    reset_password_sent_at.nil? || reset_password_sent_at < 2.hours.ago
  end

  def clear_password_reset
    self.reset_password_token = nil
    self.reset_password_sent_at = nil
    save(validate: false)
  end

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end
end
