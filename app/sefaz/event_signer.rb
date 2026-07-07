require 'nokogiri'
require 'openssl'
require 'base64'

# EventSigner — XML-DSig (Enveloped) sobre <infEvento>, perfil pinado no GATE3-Sig:
#   C14N 1.0 inclusive · SignatureMethod rsa-sha1 · Transforms [enveloped, C14N] ·
#   DigestMethod sha1 · KeyInfo EndCertOnly. Nokogiri faz o C14N; OpenSSL assina (RSA/SHA1).
# É o componente de maior risco — isolado e auto-verificável (ver #verify).
class EventSigner
  DSIG      = 'http://www.w3.org/2000/09/xmldsig#'.freeze
  NFE_NS    = 'http://www.portalfiscal.inf.br/nfe'.freeze
  C14N      = 'http://www.w3.org/TR/2001/REC-xml-c14n-20010315'.freeze
  RSA_SHA1  = 'http://www.w3.org/2000/09/xmldsig#rsa-sha1'.freeze
  ENVELOPED = 'http://www.w3.org/2000/09/xmldsig#enveloped-signature'.freeze
  SHA1      = 'http://www.w3.org/2000/09/xmldsig#sha1'.freeze
  MODE      = Nokogiri::XML::XML_C14N_1_0

  def initialize(cert:, key:)
    @cert = cert
    @key  = key
  end

  # Recebe o <evento> sem assinatura + o Id do infEvento; devolve o <evento> assinado (string).
  def sign(evento_xml, id)
    doc = Nokogiri::XML(evento_xml) { |c| c.noblanks }
    inf = doc.at_xpath('//nfe:infEvento', 'nfe' => NFE_NS) or
      raise 'infEvento não encontrado'

    digest = Base64.strict_encode64(OpenSSL::Digest::SHA1.digest(inf.canonicalize(MODE)))
    signed_info = build_signed_info(id, digest)

    # C14N do SignedInfo com o namespace ds em escopo (envolvido em <Signature xmlns=ds>)
    si = Nokogiri::XML(%(<Signature xmlns="#{DSIG}">#{signed_info}</Signature>))
           .at_xpath('//ds:SignedInfo', 'ds' => DSIG)
    signature_value = Base64.strict_encode64(@key.sign(OpenSSL::Digest::SHA1.new, si.canonicalize(MODE)))
    cert_b64 = Base64.strict_encode64(@cert.to_der)

    signature = %(<Signature xmlns="#{DSIG}">#{signed_info}) +
                %(<SignatureValue>#{signature_value}</SignatureValue>) +
                %(<KeyInfo><X509Data><X509Certificate>#{cert_b64}</X509Certificate></X509Data></KeyInfo>) +
                %(</Signature>)

    inf.add_next_sibling(signature)
    doc.root.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML |
                               Nokogiri::XML::Node::SaveOptions::NO_DECLARATION).strip
  end

  # Auto-verificação (o que a SEFAZ recalcula): confere DigestValue e SignatureValue.
  def self.verify(signed_evento_xml)
    doc = Nokogiri::XML(signed_evento_xml) { |c| c.noblanks }
    inf = doc.at_xpath('//nfe:infEvento', 'nfe' => NFE_NS)
    sig = doc.at_xpath('//ds:Signature', 'ds' => DSIG)
    dv  = doc.at_xpath('//ds:DigestValue', 'ds' => DSIG)&.text
    sv  = doc.at_xpath('//ds:SignatureValue', 'ds' => DSIG)&.text
    cert = OpenSSL::X509::Certificate.new(
      Base64.decode64(doc.at_xpath('//ds:X509Certificate', 'ds' => DSIG).text)
    )
    # digest: infEvento canonizado (Signature é irmã, logo já excluída)
    digest_ok = dv == Base64.strict_encode64(OpenSSL::Digest::SHA1.digest(inf.canonicalize(MODE)))
    si = sig.at_xpath('./ds:SignedInfo', 'ds' => DSIG)
    sig_ok = cert.public_key.verify(OpenSSL::Digest::SHA1.new, Base64.decode64(sv), si.canonicalize(MODE))
    { digest_ok: digest_ok, signature_ok: sig_ok }
  end

  private

  def build_signed_info(id, digest)
    %(<SignedInfo>) +
      %(<CanonicalizationMethod Algorithm="#{C14N}"></CanonicalizationMethod>) +
      %(<SignatureMethod Algorithm="#{RSA_SHA1}"></SignatureMethod>) +
      %(<Reference URI="##{id}">) +
      %(<Transforms>) +
      %(<Transform Algorithm="#{ENVELOPED}"></Transform>) +
      %(<Transform Algorithm="#{C14N}"></Transform>) +
      %(</Transforms>) +
      %(<DigestMethod Algorithm="#{SHA1}"></DigestMethod>) +
      %(<DigestValue>#{digest}</DigestValue>) +
      %(</Reference></SignedInfo>)
  end
end
