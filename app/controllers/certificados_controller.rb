class CertificadosController < ApplicationController
  def index
    @certificados = Certificado.order(:rotulo)
  end

  def new
    @certificado = Certificado.new
  end

  # Abre o .pfx no servidor, deriva os metadados e devolve JSON — SEM salvar.
  # O arquivo continua no browser até o "Confirmar e salvar".
  def preview
    senha  = params.dig(:certificado, :senha).to_s
    upload = params.dig(:certificado, :arquivo)
    der    = upload.respond_to?(:read) ? upload.read : nil
    info   = CertificateInspector.load(der, senha)
    render json: { ok: true, cnpj: info.cnpj, razao_social: info.razao_social,
                   validade: info.validade.to_date.iso8601, fingerprint: info.fingerprint }
  rescue ArgumentError, OpenSSL::OpenSSLError
    render json: { ok: false, error: "PFX ou senha inválidos, ou arquivo não é um .pfx/.p12 válido." },
           status: :unprocessable_entity
  end

  # Cadastro: upload .pfx + senha + rotulo -> abre na hora (valida) -> deriva CNPJ/razao/validade
  # -> cifra em repouso. O arquivo solto NÃO é persistido (Rack descarta o tempfile).
  def create
    rotulo = params.dig(:certificado, :rotulo).to_s.strip
    senha  = params.dig(:certificado, :senha).to_s
    upload = params.dig(:certificado, :arquivo)
    der    = upload.respond_to?(:read) ? upload.read : nil

    info = CertificateInspector.load(der, senha)

    @certificado = Certificado.new(
      rotulo: rotulo, cnpj: info.cnpj, razao_social: info.razao_social,
      validade: info.validade, fingerprint: info.fingerprint, senha: senha
    )
    @certificado.pfx_der = der

    if @certificado.save
      AuditEvent.record!(action: "certificado.cadastro", user: current_user,
                         certificado: @certificado,
                         detail: "rotulo=#{rotulo} cnpj=#{info.cnpj} fp=#{info.fingerprint[0, 16]}")
      redirect_to certificados_path,
                  notice: "Certificado '#{rotulo}' cadastrado: #{info.razao_social} " \
                          "(CNPJ #{info.cnpj}), validade #{info.validade.to_date.iso8601}."
    else
      @error = @certificado.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  rescue ArgumentError, OpenSSL::OpenSSLError => e
    Rails.logger.warn("[cadastro] recusado: #{e.class}") # sem detalhes sensíveis
    @certificado ||= Certificado.new(rotulo: params.dig(:certificado, :rotulo))
    @error = "PFX ou senha inválidos, ou arquivo não é um .pfx/.p12 válido."
    render :new, status: :unprocessable_entity
  end

  def destroy
    cert = Certificado.find(params[:id])
    label = cert.rotulo
    cert.destroy
    AuditEvent.record!(action: "certificado.remocao", user: current_user, detail: "rotulo=#{label}")
    redirect_to certificados_path, notice: "Certificado '#{label}' removido."
  end
end
