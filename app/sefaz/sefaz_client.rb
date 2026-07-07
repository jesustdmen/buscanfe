require 'faraday'
require 'faraday/net_http'
require 'openssl'

# Poster SOAP 1.2 / mTLS genérico (fundação reaproveitada por Distribuição e Eventos).
# SEM retry, SEM loop — cada `post` é uma chamada.
class SefazClient
  def initialize(cert:, key:, ca_file: nil, verify: true, open_timeout: 20, timeout: 60)
    @cert         = cert
    @key          = key
    @ca_file      = ca_file
    @verify       = verify
    @open_timeout = open_timeout
    @timeout      = timeout
  end

  def verify?
    @verify
  end

  def post(url:, soap_action:, body:)
    ssl = {
      client_cert: @cert,
      client_key:  @key,
      min_version: OpenSSL::SSL::TLS1_2_VERSION,
    }
    if @verify
      ssl[:verify] = true
      # bundle explícito, senão o store padrão do sistema (ca-certificates da imagem)
      ssl[:ca_file] = @ca_file if @ca_file && File.file?(@ca_file)
    else
      ssl[:verify] = false
    end

    conn = Faraday.new(url: url, ssl: ssl) { |f| f.adapter :net_http }
    conn.post do |req|
      req.options.open_timeout = @open_timeout
      req.options.timeout      = @timeout
      req.headers['Content-Type'] = %(application/soap+xml; charset=utf-8; action="#{soap_action}")
      req.body = body
    end
  end
end
