# Orquestra um lote: (opcional) Confirmação -> download. IDEMPOTENTE e RESUMÍVEL:
# rerun pula chaves já confirmadas/baixadas. Single-worker (concorrência 1 nas chamadas SEFAZ).
class LoteJob < ApplicationJob
  queue_as :default
  retry_on ConfirmacaoService::BackoffNeeded, wait: :polynomially_longer, attempts: 5

  def perform(lote_id, mode:, user_id: nil)
    lote = Lote.find(lote_id)
    user = User.find_by(id: user_id)

    if mode.to_s == "confirmar_e_baixar"
      lote.update!(status: "confirming")
      ConfirmacaoService.new(lote, user: user).run
    end

    lote.update!(status: "downloading")
    DownloadService.new(lote).run
    lote.update!(status: "done")
  end
end
