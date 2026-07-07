# Devise — auth nativa (Nível 2). bcrypt, sessão segura, paranoid, lockable, timeout.
Devise.setup do |config|
  config.mailer_sender = "no-reply@nfe-registro.local"
  require "devise/orm/active_record"

  # Enumeração de contas: mesma resposta para email inexistente/existente.
  config.paranoid = true

  # Comparação e hashing
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.stretches = Rails.env.test? ? 1 : 12          # custo bcrypt (~100-300ms)
  config.password_length = 12..128                     # mínimo sensato
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/

  # Lockable — trava após tentativas (defesa a brute force por conta)
  config.lock_strategy = :failed_attempts
  config.unlock_strategy = :time
  config.maximum_attempts = 8
  config.unlock_in = 15.minutes

  # Timeout de sessão inativa
  config.timeout_in = 30.minutes

  # Reset de senha: token de curta duração e invalida sessões
  config.reset_password_within = 15.minutes
  config.sign_out_via = :delete
  config.reconfirmable = false

  # secret_key deriva de Rails.application.secret_key_base (secret store)
end
