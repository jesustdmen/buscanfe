class DashboardController < ApplicationController
  def index
    @certificados = Certificado.order(:rotulo)
    @encryption_ready = ActiveRecord::Encryption.config.primary_key.present?
    @recent_audits = AuditEvent.order(created_at: :desc).limit(10)
  end
end
