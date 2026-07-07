require 'nokogiri'
require 'base64'
require 'zlib'
require 'stringio'

# Lê a resposta SOAP do NFeDistribuicaoDFe: cStat/xMotivo e cada docZip
# (Base64 -> GZIP -> XML), classificando procNFe (completo) x resNFe (resumo).
class DocDecoder
  Result = Struct.new(:c_stat, :x_motivo, :ult_nsu, :max_nsu, :docs, keyword_init: true)
  Doc    = Struct.new(:nsu, :schema, :xml, :root, :tipo, keyword_init: true)

  def self.parse(soap_response_body)
    doc = Nokogiri::XML(soap_response_body)
    doc.remove_namespaces! # simplifica xpath dentro do envelope SOAP

    docs = doc.xpath('//docZip').map do |dz|
      raw  = Base64.decode64(dz.text.to_s)
      xml  = gunzip(raw).force_encoding('UTF-8')
      root = Nokogiri::XML(xml).root&.name
      Doc.new(nsu: dz['NSU'], schema: dz['schema'], xml: xml, root: root,
              tipo: classify(dz['schema'], root))
    end

    Result.new(
      c_stat:   doc.at_xpath('//cStat')&.text,
      x_motivo: doc.at_xpath('//xMotivo')&.text,
      ult_nsu:  doc.at_xpath('//ultNSU')&.text,
      max_nsu:  doc.at_xpath('//maxNSU')&.text,
      docs:     docs,
    )
  end

  def self.gunzip(raw)
    Zlib::GzipReader.new(StringIO.new(raw)).read
  rescue Zlib::GzipFile::Error
    Zlib::Inflate.inflate(raw) # fallback defensivo (não é retry de rede)
  end

  def self.classify(schema, root)
    s = schema.to_s
    if s.start_with?('procNFe') || root == 'nfeProc' || root == 'NFe'
      'procNFe (NF-e COMPLETA)'
    elsif s.start_with?('resNFe') || root == 'resNFe'
      'resNFe (RESUMO)'
    elsif s.start_with?('procEventoNFe') || root == 'procEventoNFe'
      'procEventoNFe (evento completo)'
    elsif s.start_with?('resEvento') || root == 'resEvento'
      'resEvento (resumo de evento)'
    else
      "outro (schema=#{schema.inspect}, root=#{root.inspect})"
    end
  end
end
