# Fail-fast: se já existem certificados cifrados no banco, tenta decifrar UM no boot.
# Se a MASTER_PASSPHRASE estiver errada/ausente, aborta com mensagem clara — em vez de
# só descobrir quando um certificado falha em uso.
Rails.application.config.after_initialize do
  begin
    if ActiveRecord::Base.connection.table_exists?("certificados") && Certificado.exists?
      if ENV["MASTER_PASSPHRASE"].to_s.strip.empty?
        abort("\n[FATAL] MASTER_PASSPHRASE ausente e há certificados cifrados no banco — eles não abrem. Defina a passphrase e suba de novo.\n")
      end
      begin
        Certificado.order(:id).first.senha # força a decifragem (AR Encryption)
      rescue ActiveRecord::Encryption::Errors::Base
        abort("\n[FATAL] MASTER_PASSPHRASE incorreta — certificados cifrados não abrem. Corrija a passphrase e suba de novo.\n")
      end
    end
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished
    # Banco ainda não pronto (ex.: durante o db:prepare inicial) — pula a checagem.
  end
end
