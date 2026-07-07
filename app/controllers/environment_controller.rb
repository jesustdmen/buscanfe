# Seletor produção/homologação — persiste em sessão; roteia tpAmb no backend.
class EnvironmentController < ApplicationController
  def update
    amb = params[:ambiente].to_s
    session[:ambiente] = %w[producao homologacao].include?(amb) ? amb : "producao"
    redirect_back fallback_location: root_path
  end
end
