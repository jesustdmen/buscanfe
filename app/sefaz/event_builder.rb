require 'time'

# Monta o evento de Confirmação da Operação (210200), o lote envEvento e o SOAP 1.2.
# Estrutura pinada em _docs/GATE3-Sig-perfil-assinatura.md (leiaute Manifesta Destinatário v1.00).
class EventBuilder
  NFE_NS   = 'http://www.portalfiscal.inf.br/nfe'.freeze
  WSDL_NS  = 'http://www.portalfiscal.inf.br/nfe/wsdl/NFeRecepcaoEvento4'.freeze
  TP_EVENTO = '210200'.freeze
  DESC      = 'Confirmacao da Operacao'.freeze

  def initialize(tp_amb:, cnpj:, c_orgao: '91')
    @tp_amb  = tp_amb.to_s
    @cnpj    = cnpj
    @c_orgao = c_orgao.to_s
  end

  # Retorna [evento_xml_sem_assinatura, id]. dh_evento no formato TDateTimeUTC.
  def build_evento(ch_nfe:, dh_evento: nil, n_seq: 1)
    raise ArgumentError, 'chNFe deve ter 44 dígitos' unless ch_nfe.to_s =~ /\A\d{44}\z/
    dh = dh_evento || Time.now.strftime('%Y-%m-%dT%H:%M:%S%:z')
    id = "ID#{TP_EVENTO}#{ch_nfe}#{format('%02d', n_seq)}"
    xml = %(<evento xmlns="#{NFE_NS}" versao="1.00">) +
          %(<infEvento Id="#{id}">) +
          %(<cOrgao>#{@c_orgao}</cOrgao>) +
          %(<tpAmb>#{@tp_amb}</tpAmb>) +
          %(<CNPJ>#{@cnpj}</CNPJ>) +
          %(<chNFe>#{ch_nfe}</chNFe>) +
          %(<dhEvento>#{dh}</dhEvento>) +
          %(<tpEvento>#{TP_EVENTO}</tpEvento>) +
          %(<nSeqEvento>#{n_seq}</nSeqEvento>) +
          %(<verEvento>1.00</verEvento>) +
          %(<detEvento versao="1.00"><descEvento>#{DESC}</descEvento></detEvento>) +
          %(</infEvento></evento>)
    [xml, id]
  end

  # Lote envEvento — recebe 1 evento assinado OU um array (até 20) de eventos assinados.
  def env_evento(signed, id_lote: '1')
    body = Array(signed).join
    %(<envEvento xmlns="#{NFE_NS}" versao="1.00"><idLote>#{id_lote}</idLote>#{body}</envEvento>)
  end

  # Envelope SOAP 1.2: corpo é nfeDadosMsg direto (WSDL RecepcaoEvento4), sem cabecMsg.
  def soap(env_evento_xml)
    %(<?xml version="1.0" encoding="utf-8"?>) +
      %(<soap12:Envelope xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">) +
      %(<soap12:Body><nfeDadosMsg xmlns="#{WSDL_NS}">#{env_evento_xml}</nfeDadosMsg></soap12:Body>) +
      %(</soap12:Envelope>)
  end
end
