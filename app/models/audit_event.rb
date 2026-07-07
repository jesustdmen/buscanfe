# Trilha de auditoria APPEND-ONLY. Sem update/delete (imutável).
class AuditEvent < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :certificado, optional: true

  validates :action, presence: true

  before_update  { raise ActiveRecord::ReadOnlyRecord, "AuditEvent é append-only" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "AuditEvent é append-only" }

  def readonly?
    persisted?
  end

  # Registro conveniente (usado no cadastro e, futuramente, nos disparos de Confirmação).
  def self.record!(action:, user: nil, certificado: nil, chave: nil, c_stat: nil, n_prot: nil, detail: nil)
    create!(action: action, user: user, certificado: certificado,
            chave: chave, c_stat: c_stat, n_prot: n_prot, detail: detail)
  end
end
