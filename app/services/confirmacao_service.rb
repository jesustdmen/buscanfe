# Confirmação (210200) em lotes <=20, IDEMPOTENTE.
# Pula chaves já confirmadas; trata 573 (duplicidade) como "já feito".
class ConfirmacaoService
  BATCH = 20
  class BackoffNeeded < StandardError; end

  def initialize(lote, user: nil)
    @lote = lote
    @cert = lote.certificado
    @user = user
  end

  def run
    pend = @lote.chave_items.a_confirmar.to_a # status pending
    return if pend.empty?

    @cert.with_pkcs12 do |m|
      builder = EventBuilder.new(tp_amb: @lote.tp_amb, cnpj: @cert.cnpj)
      signer  = EventSigner.new(cert: m.certificate, key: m.key)
      client  = EventClient.new(tp_amb: @lote.tp_amb, cert: m.certificate, key: m.key) # verify=ON

      pend.each_slice(BATCH) do |slice|
        enviar_lote(slice, builder, signer, client)
      end
    end
  end

  private

  def enviar_lote(items, builder, signer, client)
    eventos = items.map do |item|
      evt, id = builder.build_evento(ch_nfe: item.chave, n_seq: 1)
      signer.sign(evt, id)
    end
    soap = builder.soap(builder.env_evento(eventos, id_lote: @lote.id.to_s))
    resp = client.send_event(soap)
    processar_retorno(resp.body, items)
  end

  def processar_retorno(body, items)
    doc = Nokogiri::XML(body); doc.remove_namespaces!
    lote_cstat = doc.at_xpath("//retEnvEvento/cStat")&.text || doc.at_xpath("//cStat")&.text
    raise BackoffNeeded, "lote cStat 656 (consumo indevido)" if lote_cstat == "656"

    by_chave = items.index_by(&:chave)
    doc.xpath("//retEvento").each do |ret|
      ch    = ret.at_xpath(".//chNFe")&.text
      cstat = ret.at_xpath(".//cStat")&.text
      nprot = ret.at_xpath(".//nProt")&.text
      xmot  = ret.at_xpath(".//xMotivo")&.text
      item  = by_chave[ch]
      next unless item
      registrar(item, cstat, nprot, xmot)
    end
    # itens sem retEvento correspondente (ex.: rejeição de lote): erro com cStat do lote
    items.reject { |i| i.reload.confirmada? || i.status == "error" }.each do |i|
      i.mark_error!("lote cStat #{lote_cstat}")
    end
  end

  def registrar(item, cstat, nprot, xmot)
    if %w[135 136 573].include?(cstat) # 573 = duplicidade -> já feito
      item.mark_confirmed!(c_stat: cstat, n_prot: nprot)
      AuditEvent.record!(action: "confirmacao.evento", user: @user, certificado: @cert,
                         chave: item.chave, c_stat: cstat, n_prot: nprot,
                         detail: "lote=#{@lote.id} #{xmot}")
    else
      item.mark_error!("cStat #{cstat}: #{xmot}")
      AuditEvent.record!(action: "confirmacao.rejeitada", user: @user, certificado: @cert,
                         chave: item.chave, c_stat: cstat, detail: "lote=#{@lote.id} #{xmot}")
    end
  end
end
