# buscanfe — Especificação-mestre (prompt de reconstrução "de primeira")

Este documento é a **fonte canônica** do projeto. Serve como especificação para um dev **ou**
como prompt para uma IA reconstruir a ferramenta correta na primeira tentativa, **já evitando
as armadilhas** descobridas na marra (ver seção 12).

> Convenções: valores entre `<...>` são placeholders. **Nada de segredos, CNPJs ou chaves reais
> neste arquivo** — certificados `.pfx`, `.env` e XMLs fiscais ficam fora do repositório.

---

## 1. Objetivo e escopo (travado)

Ferramenta para, sobre NF-e de **entrada** de um destinatário:
1. **Manifestar** — enviar o evento **Confirmação da Operação (210200)**, assinado com certificado A1.
2. **Baixar** o **XML completo (`procNFe`)** via `consChNFe`.

**Por quê manifestar:** sem manifestação, o destinatário só recebe o **resumo (`resNFe`)**; o
`procNFe` completo exige a Confirmação (provado empiricamente).

**Fora de escopo:** emissão, DANFE, NFC-e (mod. 65), CT-e, módulo completo de manifestação
(os 4 eventos), varredura `distNSU` em produção.

---

## 2. Stack e arquitetura

- **App única Rails** (Ruby 3.3, Rails 7.2) + **PostgreSQL** + **GoodJob** (fila DB-backed, sem Redis).
- Sem PHP / sem `sped-nfe` (avaliado e descartado: o escopo é estreito e estável; assinatura é
  risco limitado que o Ruby resolve).
- Domínio SEFAZ em `app/sefaz/` (Ruby puro): `Endpoints`, `SefazClient`, `EnvelopeBuilder`,
  `EventBuilder`, `EventSigner`, `EventClient`, `DocDecoder`.
- Serviços em `app/services/`: `CertificateInspector`, `KeyValidator`, `ConfirmacaoService`, `DownloadService`.
- Gems-chave: `nokogiri`, `faraday` + `faraday-net_http`, `devise`, `good_job`, `pg`, `rubyzip`, `rack-attack`.

---

## 3. Protocolo SEFAZ — valores pinados (Gate 1)

Fonte: **MOC v7.0** + pacote **XSD PL_NFeDistDFe_103** (arquivos `_v1.01.xsd`).

- **Namespace NF-e:** `http://www.portalfiscal.inf.br/nfe`
- **SOAP 1.2**, `Content-Type: application/soap+xml; charset=utf-8`.
- **Distribuição DFe** (`consChNFe`):
  - Operação `nfeDistDFeInteresse`; WSDL ns `.../nfe/wsdl/NFeDistribuicaoDFe`.
  - `distDFeInt` **`versao="1.01"`** (⚠️ **não** 1.35 — o 1.00 do portal é a versão do *serviço*, não do leiaute).
  - Campos p/ consChNFe: `tpAmb`, `cUFAutor` (**opcional**, `minOccurs=0`), `CNPJ`|`CPF`, `consChNFe>chNFe`(44).
  - Endpoints: prod `https://www1.nfe.fazenda.gov.br/NFeDistribuicaoDFe/NFeDistribuicaoDFe.asmx`
    · homolog `https://hom1.nfe.fazenda.gov.br/...`.
  - Corpo SOAP: **`<nfeDistDFeInteresse xmlns="wsdl-ns"><nfeDadosMsg>{distDFeInt}</nfeDadosMsg></nfeDistDFeInteresse>`**.
  - Resposta: `retDistDFeInt` → `cStat`, `xMotivo`, `loteDistDFeInt>docZip` (máx 50). **`docZip` = Base64 → GZIP → XML**.
- **RecepcaoEvento (manifestação, Ambiente Nacional)**:
  - WSDL ns `.../nfe/wsdl/NFeRecepcaoEvento4`; operação **`nfeRecepcaoEventoNF`** (via WSDL).
  - Corpo SOAP: **`<nfeDadosMsg xmlns="wsdl-ns">{envEvento}</nfeDadosMsg>`** — **sem wrapper de operação, sem `nfeCabecMsg`** (⚠️ difere da Distribuição).
  - Endpoints: prod `https://www.nfe.fazenda.gov.br/NFeRecepcaoEvento4/NFeRecepcaoEvento4.asmx`
    · homolog `https://hom1.nfe.fazenda.gov.br/...`.
- **Regras de negócio:** janela `consChNFe` = **90 dias**; vínculo exigido = **destinatário / transportador /
  terceiro (`autXML`)** — **emitente não** recebe a NF-e por aqui.
- **Tabela `cStat` relevante:**
  | cStat | Significado | Ação |
  |---|---|---|
  | 138 | Documento localizado | salvar XML |
  | 137 | Nenhum documento localizado | não recuperável |
  | 632 | Fora do prazo (>90 dias) | não recuperável |
  | 640 | Sem vínculo/permissão p/ a chave | não recuperável (cert errado) |
  | 217 | NF-e inexistente p/ a chave | não recuperável |
  | 656 | Consumo indevido (rate limit) | backoff exponencial |
  | 128 | Lote de evento processado | (nível de lote) |
  | 135 | Evento registrado **e vinculado** à NF-e | confirmado ✓ |
  | 136 | Evento registrado, **não** vinculado | confirmado (nota não existe na base) |
  | 573 | Duplicidade de evento | **tratar como "já feito"** |
  | 297/298 | Assinatura difere do calculado | erro de assinatura (a evitar) |

---

## 4. Certificado A1 / OpenSSL

- Formato **A1 `.pfx`** (PKCS#12), ICP-Brasil.
- ⚠️ **OpenSSL 3 não abre** A1 exportado com **RC2-40-CBC** (legado) por padrão. **Carregar o provider
  `legacy`** antes de abrir: `OpenSSL::Provider.load("default"); OpenSSL::Provider.load("legacy")`.
- Derivar do cert (não digitar): **CNPJ** (do CN `RAZAO:CNPJ` ou SAN OID 2.16.76.1.3.3), razão social,
  validade (`not_after`), fingerprint (SHA-256 do DER).
- **Um destinatário por lote:** a base do CNPJ (8 díg.) do cert precisa casar com o destinatário;
  cert errado → `640`, **não confirma errado**.

---

## 5. TLS `verify=ON` (obrigatório em produção)

Os certs **TLS do servidor** SEFAZ são de **CAs públicas** (não ICP-Brasil):
- `www1`/`hom1` (Distribuição) → SERPRO → **GlobalSign R46** → o `ca-certificates` do sistema **basta**.
- `www` (RecepcaoEvento, Confirmação) → **Let's Encrypt** → a cadeia servida é **incompleta** (omite o
  intermediário `ISRG/Root YR`), ancorado no **ISRG Root X1** (já confiável). **Solução:** baixar o
  intermediário via AIA (`http://yr.i.lencr.org/`) e instalá-lo no trust store da imagem
  (`COPY ca/ /usr/local/share/ca-certificates/... && update-ca-certificates`).
- Nunca contornar o verify. O bundle ICP-Brasil (ITI) só serviria p/ validar a **assinatura dos
  documentos**, não o servidor TLS.

---

## 6. Assinatura XML-DSig (o maior risco — validar em homologação primeiro)

Perfil (MOC §4.2.4), **Enveloped**, sobre a tag com `Id`:
- `CanonicalizationMethod` = `http://www.w3.org/TR/2001/REC-xml-c14n-20010315` (C14N 1.0 **inclusive**).
- `SignatureMethod` = `http://www.w3.org/2000/09/xmldsig#rsa-sha1`.
- `Reference URI="#"+Id`; **2 `Transform`**: `#enveloped-signature`, depois C14N.
- `DigestMethod` = `#sha1`; `DigestValue` = SHA-1 Base64.
- `KeyInfo` = **EndCertOnly** (só `<X509Certificate>` DER→Base64; **sem** `KeyValue`/`X509SubjectName`/etc).
- Implementação: **Nokogiri** faz o C14N (`node.canonicalize(XML_C14N_1_0)`), **OpenSSL** assina
  (`key.sign(SHA1, canonical)`). Assina `<infEvento>`; a `<Signature>` vai como **irmã, após** `infEvento`.
- **Critério de aceite (homologação):** a resposta rejeita por **regra de negócio** (ou registra 135/136),
  **não** por `297/298` (assinatura) nem `215` (schema).

### Evento Confirmação (210200) — leiaute Manifesta Destinatário v1.00
```
envEvento (xmlns=nfe, versao="1.00")
  idLote
  evento versao="1.00" (até 20)
    infEvento Id="ID"+"210200"+chNFe(44)+nSeqEvento(2)   # 54 chars, pattern ID[0-9]{52}
      cOrgao=91  tpAmb  CNPJ(destinatário)  chNFe  dhEvento(UTC±hh:mm)
      tpEvento=210200  nSeqEvento=1  verEvento=1.00
      detEvento versao="1.00" > descEvento="Confirmacao da Operacao"   # literal, sem acento
    Signature (assina infEvento)
```

---

## 7. Fluxo funcional

1. **Ingestão:** lista de chaves de UM destinatário → validar **antes** de tocar a SEFAZ.
2. **(opcional) Confirmação** em lotes ≤20 → `NFeRecepcaoEvento` → por evento, `cStat` na trilha.
3. **Propagação** (~20s) — após confirmar, o `procNFe` leva um instante.
4. **Download** `consChNFe` por chave → persiste o `procNFe`.

---

## 8. Orquestração (resiliente e resumível)

- **`KeyValidator`:** 44 dígitos, **dígito verificador módulo 11**, deduplicação. Malformada → reporta, não entra.
- **Estado por chave:** `pending → confirmed → downloaded` (+ `error`, `nao_recuperavel`).
- **`ConfirmacaoService`:** lotes **≤20**, **idempotente** (só processa `pending`; **573 = já feito**).
- **`DownloadService`:** loop **serializado + jitter**; **backoff exponencial no 656**; propagação-aware
  (`resNFe` → retry com backoff; após N tentativas volta a `confirmed` p/ próximo rerun — nota lenta não
  bloqueia o lote); `138`→salva, `137/632/640`→não recuperável. **Nunca paralelo** (paralelizar dispara 656).
- **Worker dedicado** (GoodJob, `execution_mode :external`, `max_threads 1`). Reiniciar o web não interrompe o lote.
- **Rerun idempotente** retoma de onde parou (pula `confirmed`/`downloaded`).
- **Relatório** por chave (confirmada?/cStat/baixada?/caminho/erro) + resumo.

---

## 9. Segurança

- **Cifragem em repouso** (Active Record Encryption): `encrypts :senha, :pfx_data` no modelo `Certificado`.
- **Chave-mestra** derivada de **`MASTER_PASSPHRASE`** (PBKDF2, em runtime/memória — **nunca em arquivo**;
  salt não-secreto). **Fail-fast no boot:** se há certs cifrados e a passphrase não decifra, **abortar** com msg clara.
- **Chave privada** decifrada **só em memória**; nunca logada (`filter_parameters` cobre senha/pfx/passphrase).
- **Auditoria append-only** (`before_update`/`before_destroy` levantam `ReadOnlyRecord`) — registra operador/empresa/N/timestamp/nProt.
- **Step-up** (re-passphrase, `secure_compare`) **antes** de lote de Confirmação; passphrase por request, **nunca no browser**.
- **Auth Devise** (bcrypt, `paranoid`, `lockable`, `timeoutable`); **first-run admin** (cria o 1º admin pela tela,
  **trava** após existir usuário); `rack-attack` (rate-limit login); cookies `HttpOnly/SameSite/Secure(prod)`; CSP `script-src 'self'`.

---

## 10. UI (7 telas) + 2 features

Telas: Login (Devise) · Certificados · Cadastro (upload → *preview* que deriva e valida no servidor, sem salvar → salvar cifrado) · Novo lote · Relatório · Auditoria · Setup (first-run). Design tokens (Inter + JetBrains Mono, light/dark).

1. **Chips de chave:** validação **client-side espelhando o `KeyValidator`** (44d/DV/dedup) para feedback
   instantâneo — **o backend REVALIDA no submit** (cliente nunca é autoritativo).
2. **Download em lote:** seleção múltipla no relatório → `.zip` (rubyzip) das selecionadas.

**Seletor Produção/Homologação:** roteia `tpAmb`/endpoints. **Modal de step-up consciente de ambiente** —
Produção grita (vermelho, "escrita fiscal irreversível"); Homologação avisa que é ensaio (tom calmo, tpAmb=2).
O texto do modal **corresponde ao que o backend faz** (nada cosmético).

---

## 11. Subida (um comando) + operador Windows

- `docker compose up` sobe **db (healthcheck) + web + worker**. Web roda `db:prepare` no boot (idempotente)
  e **remove `tmp/pids/server.pid` obsoleto** (senão o Puma recusa subir após shutdown abrupto).
- `MASTER_PASSPHRASE` via `.env` (local; **stdin** fica para pré-produção).
- **Atalhos** `Iniciar.bat` / `Parar.bat` (sem `-v`, preserva dados) / `Reset.bat` (exige digitar `RESETAR`),
  atalhos `.lnk` no Desktop, e **`COMO-USAR.md`** (guia sem jargão de terminal).

---

## 12. ⚠️ Armadilhas (a lista que faz acertar "de primeira")

1. `versao=1.01` no `distDFeInt` (não 1.35). `cUFAutor` é **opcional**.
2. Chave >90 dias → **632** (não 137); sem vínculo → **640**; inexistente → **217**.
3. Abrir A1 no OpenSSL 3 exige **provider `legacy`** (RC2-40).
4. `verify=ON` no `www` (RecepcaoEvento/Let's Encrypt) exige o **intermediário faltante** no trust store.
5. Corpo SOAP: **RecepcaoEvento4 = `nfeDadosMsg` direto**; **DistDFe = com wrapper `nfeDistDFeInteresse`**.
6. `docZip` = **Base64 → GZIP → XML** (esquecer o GZIP = "veio vazio").
7. Confirmação: `cOrgao=91`, `descEvento="Confirmacao da Operacao"` (sem acento), `Id` de 54 chars.
8. **Nunca paralelizar** chamadas SEFAZ (dispara 656 e bloqueia por minutos).
9. **Idempotência antes de reprocessar** (pular confirmadas; 573 = já feito) — rerun não pode redisparar Confirmação.
10. Destinatário não-manifestado → `resNFe`; só após Confirmação vem `procNFe`.
11. `tmp/pids/server.pid` obsoleto trava o Puma após restart abrupto — limpar no boot.
12. Segredos/`.pfx`/XMLs fiscais **nunca** no git (`.gitignore` + gitleaks no CI).

---

## 13. Fora de escopo / hardening pendente (pré-produção)

`MASTER_PASSPHRASE` por **stdin** (não `.env`) · **Argon2id** (no lugar do bcrypt) · **`force_ssl`/TLS** ·
apertar **CSP** (remover `unsafe-inline` de estilos) · **reset de senha** (SMTP) / tela de alterar senha.
Integração ≠ produção.
