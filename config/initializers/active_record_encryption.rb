# Active Record Encryption com chave-mestra DERIVADA de uma passphrase fornecida
# na subida (ENV, só em memória — NUNCA em arquivo). Sem a passphrase, colunas com
# `encrypts` não podem ser cifradas/decifradas: é o design (chave-mestra fora dos dados).
require "openssl"
require "base64"

passphrase = ENV["MASTER_PASSPHRASE"].to_s
if passphrase.strip.empty?
  Rails.logger.warn("[encryption] MASTER_PASSPHRASE ausente — cifragem indisponível até subir com a passphrase.")
else
  # salt NÃO-secreto (contexto/versão). O segredo é a passphrase.
  salt = ENV.fetch("MASTER_KEY_SALT", "nfe-registro/v1")
  derive = lambda do |info|
    OpenSSL::KDF.pbkdf2_hmac(passphrase, salt: "#{salt}:#{info}", iterations: 210_000,
                             length: 32, hash: "SHA256")
  end

  ActiveRecord::Encryption.configure(
    primary_key:         Base64.strict_encode64(derive.call("primary")),
    deterministic_key:   Base64.strict_encode64(derive.call("deterministic")),
    key_derivation_salt: Base64.strict_encode64(derive.call("kds")),
  )
  ActiveRecord::Encryption.config.support_unencrypted_data = false
  Rails.logger.info("[encryption] AR Encryption configurado a partir da passphrase (em memória).")
end
