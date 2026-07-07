require "openssl"

# Abre um A1 (.pfx) em memória, valida (pfx+senha) e DERIVA os metadados
# (cnpj/razao/validade/fingerprint). Nunca loga a chave privada.
module CertificateInspector
  Result = Struct.new(:certificate, :key, :cnpj, :razao_social, :validade, :fingerprint,
                      keyword_init: true)

  module_function

  # A1 ICP-Brasil podem usar RC2-legacy (OpenSSL 3 → provider "legacy").
  def ensure_legacy!
    return if defined?(@legacy_loaded) && @legacy_loaded
    OpenSSL::Provider.load("default")
    OpenSSL::Provider.load("legacy")
    @legacy_loaded = true
  rescue StandardError => e
    Rails.logger.warn("[cert] provider legacy indisponível: #{e.message}")
  end

  # Levanta OpenSSL::PKCS12::PKCS12Error se pfx/senha inválidos.
  def load(der_bytes, senha)
    ensure_legacy!
    raise ArgumentError, "arquivo .pfx vazio" if der_bytes.nil? || der_bytes.empty?
    p12  = OpenSSL::PKCS12.new(der_bytes, senha.to_s)
    cert = p12.certificate
    key  = p12.key
    raise ArgumentError, "certificado/chave ausentes no .pfx" unless cert && key

    Result.new(certificate: cert, key: key,
               cnpj: cnpj_of(cert), razao_social: razao_of(cert),
               validade: cert.not_after, fingerprint: fingerprint_of(cert))
  end

  def cnpj_of(cert)
    cn = common_name(cert)
    from_cn = cn[/:(\d{14})\b/, 1]
    return from_cn if from_cn
    san = cert.extensions.find { |e| e.oid == "subjectAltName" }
    san&.value.to_s.scan(/\d{14}/)&.first
  end

  def razao_of(cert)
    common_name(cert).sub(/:\d{11,14}\b.*/, "").strip
  end

  def fingerprint_of(cert)
    OpenSSL::Digest::SHA256.hexdigest(cert.to_der)
  end

  def common_name(cert)
    cert.subject.to_a.find { |name,| name == "CN" }&.dig(1).to_s
  end
end
