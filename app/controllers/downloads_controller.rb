class DownloadsController < ApplicationController
  # Tela de download: dropdown por rótulo escolhe o certificado.
  def show
    @certificados = Certificado.order(:rotulo)
    @selected = Certificado.find_by(id: params[:certificado_id])
  end

  # Placeholder do lote de Confirmação (a ORQUESTRAÇÃO é Fase 4 parte 2).
  # Aqui só provamos: exige step-up + registra auditoria. NÃO dispara nada na SEFAZ.
  def confirmar
    require_step_up!
    return if performed?

    cert = Certificado.find(params[:certificado_id])
    AuditEvent.record!(action: "confirmacao.autorizada", user: current_user, certificado: cert,
                       detail: "step-up ok; lote não executado (orquestração = Fase 4 parte 2)")
    redirect_to download_path(certificado_id: cert.id),
                notice: "Step-up confirmado e autorização registrada para '#{cert.rotulo}'. " \
                        "Execução do lote é a Fase 4 parte 2."
  end
end
