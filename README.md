# Console NF-e — Manifestação + Download de XML

Aplicação web (Rails + Postgres + GoodJob) para **Confirmação da Operação (evento 210200,
assinada com certificado A1)** e **download do XML completo (`procNFe`)** de NF-e de entrada.

- Registro de certificados A1 cifrado em repouso (Active Record Encryption).
- Ingestão de chaves com validação (44 dígitos, dígito verificador, dedup).
- Confirmação em lotes (≤20), idempotente; download serializado com backoff.
- Worker dedicado (GoodJob) processando a fila; seletor **Produção/Homologação**.
- Trilha de auditoria append-only.

## 🚀 Subir (um comando)

Pré-requisito: **Docker Desktop** aberto e "verde".

```bash
cp .env.example .env      # e defina MASTER_PASSPHRASE (chave do cofre)
docker compose up         # ou os atalhos de Windows: Iniciar.bat
```

- UI: **http://localhost:3000**
- **Primeiro acesso:** sem usuário, a tela pede para **criar o administrador** (e-mail + senha ≥ 12).
  Depois, o acesso é sempre pelo login. A tela de setup fecha assim que existe um admin.
- Parar (preservando dados): `docker compose down` (ou `Parar.bat`).
- **Operador Windows:** use os atalhos `Iniciar.bat` / `Parar.bat` / `Reset.bat` e o guia
  **[COMO-USAR.md](COMO-USAR.md)** (linguagem simples, sem terminal).

## Segurança (local/dev)

- `MASTER_PASSPHRASE` vem do `.env` (local) e é validada no boot (fail-fast se não decifrar os certificados).
- Certificados (`.pfx`), senhas e XMLs baixados **nunca** vão para o git (ver `.gitignore`).
- Passo de step-up (re-passphrase) antes de escrita fiscal; modal consciente de ambiente.

## Pendente antes de produção (hardening)

Passphrase por **stdin** (não `.env`), **Argon2id**, **`force_ssl`/TLS**, apertar o **CSP**
(remover `unsafe-inline`), e **reset de senha** (SMTP). Integração ≠ produção.

## Estrutura

```
app/            models, controllers, views, jobs
app/sefaz/      domínio SEFAZ (EventSigner/EventBuilder/SefazClient/DocDecoder/Endpoints)
app/services/   CertificateInspector, KeyValidator, Confirmacao/Download services
config/         rotas, initializers (AR Encryption, GoodJob, CSP, checagem da passphrase)
ca/             intermediário TLS (Let's Encrypt) p/ verify=ON no endpoint www
docker-compose.yml  Dockerfile.dev  Iniciar/Parar/Reset.bat  COMO-USAR.md
```
