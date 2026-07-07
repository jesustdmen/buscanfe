class Lote < ApplicationRecord
  belongs_to :certificado
  belongs_to :user, optional: true
  has_many :chave_items, dependent: :destroy

  STATUSES = %w[open confirming downloading done].freeze
  validates :status, inclusion: { in: STATUSES }

  # Um destinatário por lote: o CNPJ é o do certificado.
  def cnpj
    certificado.cnpj
  end

  def resumo
    grp = chave_items.group(:status).count
    {
      total:      chave_items.count,
      pending:    grp["pending"].to_i,
      confirmed:  grp["confirmed"].to_i + grp["downloaded"].to_i, # já confirmadas
      downloaded: grp["downloaded"].to_i,
      erros:      grp["error"].to_i + grp["nao_recuperavel"].to_i,
    }
  end
end
