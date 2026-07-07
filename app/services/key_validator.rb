# Validação/curadoria da lista ANTES de tocar a SEFAZ: 44 dígitos, dígito verificador, dedup.
module KeyValidator
  module_function

  # DV por módulo 11 (pesos 2..9 da direita) sobre os 43 primeiros dígitos.
  def dv_ok?(chave)
    return false unless chave.to_s =~ /\A\d{44}\z/
    w = 2; s = 0
    chave[0, 43].reverse.each_char { |c| s += c.to_i * w; w = w == 9 ? 2 : w + 1 }
    r = s % 11
    dv = r <= 1 ? 0 : 11 - r
    dv == chave[43].to_i
  end

  # raw: texto/lista bruta. -> { validas: [chave], rejeitadas: [{chave, motivo}] }
  def curate(raw)
    seen = {}
    validas = []
    rejeitadas = []
    tokens(raw).each do |orig|
      ch = orig.gsub(/\D/, "")
      if ch.length != 44
        rejeitadas << { chave: orig, motivo: "não tem 44 dígitos" }
      elsif !dv_ok?(ch)
        rejeitadas << { chave: ch, motivo: "dígito verificador inválido" }
      elsif seen[ch]
        rejeitadas << { chave: ch, motivo: "duplicada" }
      else
        seen[ch] = true
        validas << ch
      end
    end
    { validas: validas, rejeitadas: rejeitadas }
  end

  def tokens(raw)
    raw.to_s.split(/[\s,;]+/).reject(&:empty?)
  end
end
