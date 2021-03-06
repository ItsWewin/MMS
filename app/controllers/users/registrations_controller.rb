class Users::RegistrationsController < Devise::RegistrationsController
  # before_action :configure_sign_up_params, only: [:create]
  # before_action :configure_account_update_params, only: [:update]

  layout 'registrations'
  before_action :captcha_validated?, only: [:create]
  before_action :invitation_code_validated?, only: [:create]
  before_action :can_sigin_up?, only: [:create]

  #after_create :generate_md5_password
  # GET /resource/sign_up
  def new
    @invitation_code = params[:invitation_code]
    super
  end

  # POST /resource
  def create
    super
  end

  # GET /resource/edit
  # def edit
  #   super
  # end

  # PUT /resource
  # def update
  #   super
  # end

  # DELETE /resource
  # def destroy
  #   super
  # end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  # def cancel
  #   super
  # end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_up_params
  #   devise_parameter_sanitizer.permit(:sign_up, keys: [:attribute])
  # end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_account_update_params
  #   devise_parameter_sanitizer.permit(:account_update, keys: [:attribute])
  # end

  # The path used after sign up.
  # def after_sign_up_path_for(resource)
  #   super(resource)
  # end

  # The path used after sign up for inactive accounts.
  # def after_inactive_sign_up_path_for(resource)
  #   super(resource)
  # end

  def captcha_validated?
    unless verify_rucaptcha?
      return redirect_to :back, alert: '验证码输入不正确'
    end
  end

  def invitation_code_validated?
    system_setting = SystemSetting.first
    if system_setting.need_invitation_code?
      return redirect_to :back, alert: '必须输入邀请码' unless params[:user][:h_invitation_code].present?
    end

    if params[:user][:h_invitation_code].present?
      u = User.find_by_invitation_code(params[:user][:h_invitation_code])
      unless u.present? && u.level.number > 1
        return redirect_to :back, alert: '邀请码无效'
      end

      unless u.can_invite
        return redirect_to :back, alert: '此邀请码暂时禁用'
      end
    end
  end

  def can_sigin_up?
    unless SystemSetting.first.can_sigin_up
      return redirect_to :back, alert: '系统已关闭注册功能，请稍后重试'
    end
  end
end
