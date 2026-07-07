class Certificado < ApplicationRecord
  # Segredos cifrados em repouso (Active Record Encryption; chave-mestra via passphrase).
  encrypts :senha
  encrypts :pfx_data # guarda Base64(DER) cifrado

  # rotulo é o ÚNICO campo digitado. cnpj/razao/validade/fingerprint são DERIVADOS do cert.
  validates :rotulo, presence: true, uniqueness: true
  validates :cnpj, :razao_social, :validade, :fingerprint, presence: true
  validates :fingerprint, uniqueness: true

  has_many :audit_events, dependent: :restrict_with_exception

  # Bytes DER do .pfx (nunca logados; ver filter_parameters).
  def pfx_der=(bytes)
    self.pfx_data = bytes && Base64.strict_encode64(bytes)
  end

  def pfx_der
    Base64.decode64(pfx_data) if pfx_data.present?
  end

  # Decifra e abre o PKCS12 SÓ em memória. A chave privada nunca é persistida/logada.
  # Use dentro de um bloco: o resultado não deve ser guardado.
  def with_pkcs12
    material = CertificateInspector.load(pfx_der, senha)
    yield material
  ensure
    material = nil # incentiva GC; evita retenção da chave
  end

  def expirado?
    validade.present? && validade < Time.current
  end

  def to_s
    rotulo
  end
end
