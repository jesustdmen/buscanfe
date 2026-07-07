# Download do procNFe via consChNFe, SERIALIZADO (nunca paralelo).
# resNFe (não propagou) -> retry com backoff; 656 -> backoff exponencial; 138 -> persiste.
# 137/632/640 -> não recuperável. Nota lenta não bloqueia: volta a 'confirmed' p/ próximo rerun.
class DownloadService
  MAX_PROP_RETRY = 5
  MAX_656_RETRY  = 6

  NAO_RECUPERAVEL = {
    "137" => "nenhum documento localizado",
    "632" => "fora do prazo (90 dias)",
    "640" => "sem permissão (vínculo) para a chave",
  }.freeze

  # sleep_fn e rand_fn injetáveis (testes rodam rápido). jitter_max em segundos.
  def initialize(lote, sleep_fn: method(:sleep), jitter_max: 1.0, rand_fn: Kernel.method(:rand))
    @lote = lote
    @cert = lote.certificado
    @sleep = sleep_fn
    @jitter_max = jitter_max
    @rand = rand_fn
  end

  def run
    items = @lote.chave_items.a_baixar.to_a # status confirmed
    return if items.empty?

    @cert.with_pkcs12 do |m|
      client  = SefazClient.new(cert: m.certificate, key: m.key) # verify=ON (store do sistema)
      builder = EnvelopeBuilder.new(tp_amb: @lote.tp_amb, cnpj: @cert.cnpj)
      url = Endpoints::DIST.fetch(@lote.tp_amb)
      items.each { |item| baixar(item, client, builder, url) } # SERIALIZADO
    end
  end

  private

  def baixar(item, client, builder, url)
    prop = 0
    back = 2
    tries656 = 0
    loop do
      pausa # jitter entre chamadas
      soap = builder.soap_envelope(item.chave)
      res  = DocDecoder.parse(client.post(url: url, soap_action: Endpoints::DIST_ACTION, body: soap).body)
      cstat = res.c_stat
      doc   = res.docs.first
      item.increment!(:attempts)

      if doc&.tipo&.start_with?("procNFe")
        path = persistir(item.chave, doc.xml)
        item.mark_downloaded!(c_stat: cstat, tipo: "procNFe", xml_path: path)
        return
      elsif doc&.tipo&.start_with?("resNFe")
        prop += 1
        return if prop >= MAX_PROP_RETRY # deixa 'confirmed' -> próximo rerun pega (não bloqueia)
        @sleep.call([2**prop, 30].min)
      elsif cstat == "656"
        tries656 += 1
        return item.mark_error!("656 consumo indevido (excedeu retries)") if tries656 > MAX_656_RETRY
        @sleep.call(back)
        back = [back * 2, 60].min
      elsif NAO_RECUPERAVEL.key?(cstat)
        item.mark_nao_recuperavel!(c_stat: cstat, motivo: NAO_RECUPERAVEL[cstat])
        return
      else
        item.mark_error!("cStat #{cstat}: #{res.x_motivo}")
        return
      end
    end
  end

  def persistir(chave, xml)
    dir = Rails.root.join("storage", "xml")
    FileUtils.mkdir_p(dir)
    path = dir.join("#{chave}.xml")
    File.write(path, xml)
    "storage/xml/#{chave}.xml"
  end

  def pausa
    @sleep.call(@rand.call * @jitter_max) if @jitter_max.positive?
  end
end
