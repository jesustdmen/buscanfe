# Step-up: reconfirmação da passphrase-mestra antes de ações sensíveis.
class StepUpController < ApplicationController
  def new
    @return_to = params[:return_to]
  end

  def create
    entered = params[:passphrase].to_s
    master  = ENV["MASTER_PASSPHRASE"].to_s
    ok = master.present? && ActiveSupport::SecurityUtils.secure_compare(entered, master)

    if ok
      session[:step_up_until] = 10.minutes.from_now.to_i
      AuditEvent.record!(action: "step_up.ok", user: current_user)
      redirect_to(safe_return(params[:return_to]), notice: "Step-up confirmado (válido por 10 min).")
    else
      AuditEvent.record!(action: "step_up.falha", user: current_user)
      @return_to = params[:return_to]
      flash.now[:alert] = "Passphrase-mestra incorreta."
      render :new, status: :unprocessable_entity
    end
  end

  private

  # Evita open-redirect: só caminhos internos.
  def safe_return(path)
    path.to_s.start_with?("/") && !path.to_s.start_with?("//") ? path : root_path
  end
end
