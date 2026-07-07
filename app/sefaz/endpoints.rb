# Endpoints e SOAPActions pinados (GATE1 + GATE3-Sig). Chave = tpAmb ('1' prod, '2' homolog).
module Endpoints
  DIST = {
    '1' => 'https://www1.nfe.fazenda.gov.br/NFeDistribuicaoDFe/NFeDistribuicaoDFe.asmx',
    '2' => 'https://hom1.nfe.fazenda.gov.br/NFeDistribuicaoDFe/NFeDistribuicaoDFe.asmx',
  }.freeze
  DIST_ACTION = 'http://www.portalfiscal.inf.br/nfe/wsdl/NFeDistribuicaoDFe/nfeDistDFeInteresse'.freeze

  # NFeRecepcaoEvento (Ambiente Nacional) — manifestação do destinatário
  EVENT = {
    '1' => 'https://www.nfe.fazenda.gov.br/NFeRecepcaoEvento4/NFeRecepcaoEvento4.asmx',
    '2' => 'https://hom1.nfe.fazenda.gov.br/NFeRecepcaoEvento4/NFeRecepcaoEvento4.asmx',
  }.freeze
  EVENT_ACTION = 'http://www.portalfiscal.inf.br/nfe/wsdl/NFeRecepcaoEvento4/nfeRecepcaoEventoNF'.freeze
end
