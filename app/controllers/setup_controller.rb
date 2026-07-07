# First-run admin. Só funciona enquanto NÃO existe nenhum usuário (trava de segurança):
# assim que um admin existe, /setup redireciona para o login — ninguém cria admin depois.
class SetupController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :block_if_users_exist

  def new
    @user = User.new
  end

  def create
    @user = User.new(setup_params)
    if @user.save
      sign_in(@user)
      AuditEvent.record!(action: "admin.criado", user: @user, detail: "first-run admin")
      redirect_to root_path, notice: "Administrador criado. Bem-vindo(a)."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def setup_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end

  # A trava: se já há usuário, o setup está fechado.
  def block_if_users_exist
    redirect_to new_user_session_path, alert: "Setup já concluído — faça login." if User.exists?
  end
end
