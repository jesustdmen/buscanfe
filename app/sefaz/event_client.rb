# EventClient — envia o SOAP do evento ao NFeRecepcaoEvento (AN) por tpAmb.
# (Endpoints e SefazClient são autoload — sem require_relative no Rails.)
class EventClient
  attr_reader :url

  def initialize(tp_amb:, cert:, key:, ca_file: nil, verify: true)
    @url    = Endpoints::EVENT.fetch(tp_amb.to_s) { raise ArgumentError, "tpAmb inválido: #{tp_amb}" }
    @client = SefazClient.new(cert: cert, key: key, ca_file: ca_file, verify: verify)
  end

  def verify?
    @client.verify?
  end

  def send_event(soap_xml)
    @client.post(url: @url, soap_action: Endpoints::EVENT_ACTION, body: soap_xml)
  end
end
