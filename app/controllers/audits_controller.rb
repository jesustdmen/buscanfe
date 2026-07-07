class AuditsController < ApplicationController
  def index
    @audits = AuditEvent.includes(:user, :certificado).order(created_at: :desc).limit(200)
  end
end
