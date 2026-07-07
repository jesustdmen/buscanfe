require "zip"

class LotesController < ApplicationController
  def new
    @certificados = Certificado.order(:rotulo)
    @certificado = Certificado.find_by(id: params[:certificado_id]) || @certificados.first
  end

  # Ingestão + validação (44d/DV/dedup) — o BACKEND é autoritativo (revalida o que veio do cliente).
  def create
    cert = Certificado.find(params[:certificado_id])
    result = KeyValidator.curate(params[:chaves])

    if result[:validas].empty?
      @certificados = Certificado.order(:rotulo)
      @certificado = cert
      @rejeitadas = result[:rejeitadas]
      flash.now[:alert] = "Nenhuma chave válida na lista."
      return render :new, status: :unprocessable_entity
    end

    lote = Lote.create!(certificado: cert, user: current_user, status: "open", tp_amb: current_tp_amb)
    result[:validas].each { |ch| lote.chave_items.create!(chave: ch, status: "pending") }
    AuditEvent.record!(action: "lote.criado", user: current_user, certificado: cert,
                       detail: "lote=#{lote.id} amb=#{current_ambiente} validas=#{result[:validas].size} rejeitadas=#{result[:rejeitadas].size}")

    flash[:rejeitadas] = result[:rejeitadas].first(50)
    redirect_to lote_path(lote), notice: "Lote ##{lote.id}: #{result[:validas].size} válidas, #{result[:rejeitadas].size} rejeitadas."
  end

  def show
    @lote = Lote.find(params[:id])
    @items = @lote.chave_items.order(:id)
    @resumo = @lote.resumo
    @rejeitadas = flash[:rejeitadas]
  end

  # Fatia READ-ONLY: só download das já confirmadas. Sem escrita fiscal.
  def baixar
    lote = Lote.find(params[:id])
    LoteJob.perform_later(lote.id, mode: "baixar", user_id: current_user.id)
    redirect_to lote_path(lote), notice: "Download enfileirado (loop serializado + backoff)."
  end

  # Fatia de ESCRITA: STEP-UP no próprio request (passphrase-mestra, nunca guardada no browser).
  # tpAmb vem do ambiente do lote (produção OU homologação = ensaio).
  def confirmar
    lote = Lote.find(params[:id])
    entered = params[:passphrase].to_s
    master  = ENV["MASTER_PASSPHRASE"].to_s

    unless master.present? && ActiveSupport::SecurityUtils.secure_compare(entered, master)
      AuditEvent.record!(action: "step_up.falha", user: current_user, certificado: lote.certificado,
                         detail: "lote=#{lote.id}")
      return redirect_to lote_path(lote), alert: "Passphrase-mestra incorreta — confirmação NÃO realizada."
    end

    n = lote.chave_items.a_confirmar.count
    amb = lote.tp_amb == "2" ? "homologacao(ensaio)" : "producao"
    AuditEvent.record!(action: "lote.confirmacao_autorizada", user: current_user,
                       certificado: lote.certificado,
                       detail: "lote=#{lote.id} amb=#{amb} empresa=#{lote.cnpj} N=#{n} step-up ok")
    LoteJob.perform_later(lote.id, mode: "confirmar_e_baixar", user_id: current_user.id)
    redirect_to lote_path(lote), notice: "Confirmação de #{n} nota(s) (#{amb}) autorizada e enfileirada."
  end

  # Download em lote: zipa os XMLs das chaves selecionadas (já em storage).
  def download_zip
    lote = Lote.find(params[:id])
    chaves = Array(params[:chaves]).select { |c| c.to_s =~ /\A\d{44}\z/ }
    items = lote.chave_items.where(chave: chaves, status: "downloaded")
    if items.empty?
      return redirect_to lote_path(lote), alert: "Nenhuma nota baixada selecionada."
    end
    buffer = Zip::OutputStream.write_buffer do |zos|
      items.each do |it|
        path = Rails.root.join(it.xml_path.to_s)
        next unless it.xml_path.present? && File.exist?(path)
        zos.put_next_entry("#{it.chave}.xml")
        zos.write File.binread(path)
      end
    end
    buffer.rewind
    send_data buffer.read, filename: "lote-#{lote.id}-#{items.size}-xmls.zip", type: "application/zip"
  end

  # Download individual do XML de uma chave.
  def xml
    lote = Lote.find(params[:id])
    item = lote.chave_items.find_by!(chave: params[:chave], status: "downloaded")
    send_file Rails.root.join(item.xml_path), filename: "#{item.chave}.xml", type: "application/xml"
  end
end
