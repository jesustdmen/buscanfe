require 'nokogiri'

# Monta o distDFeInt (versao 1.01, valores pinados no GATE1) para consChNFe
# e o embrulha no envelope SOAP 1.2 (operação nfeDistDFeInteresse).
class EnvelopeBuilder
  NS_NFE  = 'http://www.portalfiscal.inf.br/nfe'.freeze
  NS_WSDL = 'http://www.portalfiscal.inf.br/nfe/wsdl/NFeDistribuicaoDFe'.freeze
  VERSAO  = '1.01'.freeze

  def initialize(tp_amb:, cnpj: nil, cpf: nil, cuf_autor: nil)
    @tp_amb    = tp_amb.to_s
    @cnpj      = cnpj
    @cpf       = cpf
    @cuf_autor = cuf_autor
  end

  # XML interno distDFeInt (sem declaração XML; vai dentro de nfeDadosMsg)
  def dist_dfe_int(ch_nfe)
    raise ArgumentError, 'chNFe deve ter 44 dígitos' unless ch_nfe.to_s =~ /\A\d{44}\z/

    b = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.distDFeInt(xmlns: NS_NFE, versao: VERSAO) do
        xml.tpAmb @tp_amb
        xml.cUFAutor @cuf_autor if @cuf_autor && !@cuf_autor.to_s.empty?  # campo OPCIONAL
        if @cnpj && !@cnpj.to_s.empty?
          xml.CNPJ @cnpj
        elsif @cpf && !@cpf.to_s.empty?
          xml.CPF @cpf
        else
          raise ArgumentError, 'Informe CNPJ ou CPF do interessado'
        end
        xml.consChNFe do
          xml.chNFe ch_nfe
        end
      end
    end
    no_decl = Nokogiri::XML::Node::SaveOptions::AS_XML |
              Nokogiri::XML::Node::SaveOptions::NO_DECLARATION
    b.doc.root.to_xml(save_with: no_decl).strip
  end

  # Envelope SOAP 1.2 com o distDFeInt embutido em nfeDadosMsg.
  # NFeDistribuicaoDFe NÃO usa nfeCabecMsg (sem versaoDados no header).
  def soap_envelope(ch_nfe)
    inner = dist_dfe_int(ch_nfe)
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <soap12:Envelope xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
        <soap12:Body>
          <nfeDistDFeInteresse xmlns="#{NS_WSDL}">
            <nfeDadosMsg>#{inner}</nfeDadosMsg>
          </nfeDistDFeInteresse>
        </soap12:Body>
      </soap12:Envelope>
    XML
  end
end
