class PasswordsController < Devise::PasswordsController
  before_action :resource_from_email, only: [:create]
  before_action :prevent_ldap_reset,  only: [:create]
  before_action :throttle_reset,      only: [:create]

  def edit
    super
    reset_password_token = Devise.token_generator.digest(
      User,
      :reset_password_token,
      resource.reset_password_token
    )

    unless reset_password_token.nil?
      user = User.where(
        reset_password_token: reset_password_token
      ).first_or_initialize

      unless user.reset_password_period_valid?
        flash[:alert] = 'Your password reset token has expired.'
        redirect_to(new_user_password_url(user_email: user['email']))
      end
    end
  end

  protected

  def resource_from_email
    email = resource_params[:email]
    self.resource = resource_class.find_by_email(email)
  end

  def prevent_ldap_reset
    return unless resource && resource.ldap_user?

    redirect_to after_sending_reset_password_instructions_path_for(resource_name),
      alert: "Cannot reset password for LDAP user."
  end

  def throttle_reset
    return unless resource && resource.recently_sent_password_reset?

    redirect_to new_password_path(resource_name),
      alert: I18n.t('devise.passwords.recently_reset')
  end
end
