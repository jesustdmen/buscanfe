# Estado por chave: pending -> confirmed -> downloaded (ou error / nao_recuperavel).
# Idempotência: rerun pula 'confirmed'/'downloaded'.
class ChaveItem < ApplicationRecord
  belongs_to :lote

  STATUSES = %w[pending confirmed downloaded error nao_recuperavel].freeze
  validates :status, inclusion: { in: STATUSES }
  validates :chave, presence: true, format: { with: /\A\d{44}\z/ }

  scope :pending,      -> { where(status: "pending") }
  scope :a_confirmar,  -> { where(status: "pending") }
  scope :a_baixar,     -> { where(status: "confirmed") }
  scope :downloaded,   -> { where(status: "downloaded") }
  scope :em_erro,      -> { where(status: %w[error nao_recuperavel]) }

  def confirmada? = %w[confirmed downloaded].include?(status)
  def baixada?    = status == "downloaded"

  def mark_confirmed!(c_stat:, n_prot: nil)
    update!(status: "confirmed", c_stat_evento: c_stat, n_prot: n_prot, error: nil)
  end

  def mark_downloaded!(c_stat:, tipo:, xml_path:)
    update!(status: "downloaded", c_stat_download: c_stat, tipo: tipo, xml_path: xml_path, error: nil)
  end

  def mark_nao_recuperavel!(c_stat:, motivo:)
    update!(status: "nao_recuperavel", c_stat_download: c_stat, error: motivo)
  end

  def mark_error!(motivo)
    update!(status: "error", error: motivo.to_s[0, 300])
  end
end
