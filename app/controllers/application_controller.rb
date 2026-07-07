class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :ensure_setup!
  before_action :authenticate_user!

  private

  # First-run: sem nenhum usuário, todo acesso vai para a tela de criar administrador.
  def ensure_setup!
    return if User.exists?
    return if request.path.start_with?("/setup")
    redirect_to new_setup_path
  end

  # Step-up: ações sensíveis exigem re-confirmação recente da passphrase-mestra.
  def require_step_up!
    return if session[:step_up_until].to_i > Time.current.to_i
    redirect_to new_step_up_path(return_to: request.fullpath),
                alert: "Ação sensível: reconfirme a passphrase-mestra."
  end

  def step_up_active?
    session[:step_up_until].to_i > Time.current.to_i
  end
  helper_method :step_up_active?

  # Ambiente selecionado (produção/homologação) -> roteia tpAmb/endpoints no backend.
  def current_ambiente
    session[:ambiente] == "homologacao" ? "homologacao" : "producao"
  end

  def current_tp_amb
    current_ambiente == "homologacao" ? "2" : "1"
  end
  helper_method :current_ambiente, :current_tp_amb
end
