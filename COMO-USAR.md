# Console NF-e — Como usar

Guia simples para o dia a dia. Você não precisa de terminal: é tudo por atalhos e pelo navegador.

---

## Antes de começar (uma vez)

1. Abra o **Docker Desktop** (ícone da baleia).
2. Espere o indicador dele ficar **verde** ("Engine running"). Isso pode levar um minuto.
   - Enquanto não estiver verde, o Console não sobe.

Na sua **Área de Trabalho** existem três atalhos:

- 🟢 **NF-e — Iniciar**
- ⏹️ **NF-e — Parar**
- ⚠️ **NF-e — RESET (apaga tudo)**

---

## Iniciar

**Dê dois cliques em "NF-e — Iniciar".**

- Uma janela preta aparece por alguns segundos (é normal). Na primeira vez pode demorar mais.
- Quando ficar pronto, o **navegador abre sozinho** em `http://localhost:3000`.
- Se aparecer erro pedindo o Docker: abra o Docker Desktop, espere ficar verde e clique em Iniciar de novo.

## Primeiro acesso — criar o administrador

Na **primeira vez**, a tela pede para **Criar administrador**:

- Informe um **e-mail** e uma **senha** (mínimo 12 caracteres) e confirme.
- Pronto: você entra no console. Essa tela **só aparece uma vez** — depois, o acesso é sempre pelo login.

> Guarde bem essa senha. Ela é a sua entrada no sistema.

---

## Uso no dia a dia

### 1) Cadastrar um certificado (uma vez por empresa)

Menu **Certificados → Adicionar certificado**:
- Dê um **rótulo** (ex.: "Matriz").
- Escolha o arquivo **.pfx** e digite a **senha do certificado**.
- Clique em **Ler e validar**. O sistema mostra CNPJ, razão social e validade lidos do próprio certificado.
- Confira e clique em **Confirmar e salvar**. O certificado fica guardado com segurança (cifrado).

### 2) Criar um lote e baixar as notas

Menu **Novo lote**:
- Escolha a **empresa** (certificado).
- **Cole a lista de chaves** (44 dígitos cada). Cada chave vira um balão: **verde** = válida, **vermelho** = rejeitada (com o motivo). O ✕ remove.
- Clique em **Criar lote**.

No **relatório do lote** você tem duas ações:

- **Baixar (read-only)** — só baixa notas que **já foram confirmadas**. Não altera nada na Receita.
- **Confirmar e baixar** — faz a **Confirmação da Operação** (assinada) e depois baixa. Isso é **escrita fiscal**.

### 3) Homologação antes de produção (recomendado)

No topo há um seletor **Ambiente: Produção / Homologação**.

- Em **Homologação** a Confirmação é um **ensaio**: nada é gravado de verdade na Receita. Use para testar o fluxo com tranquilidade.
- Em **Produção**, a Confirmação é **real e irreversível**. Ao clicar em "Confirmar e baixar", uma janela **vermelha** avisa e pede a **passphrase-mestra**.
  - Em Homologação, a mesma janela aparece em tom **calmo** dizendo que é ensaio.
- **Sempre confira a cor e o texto da janela** antes de confirmar: ela diz exatamente o que vai acontecer.

### 4) Baixar os XML

No relatório, quando as notas estiverem **Baixadas**:
- Baixe **uma** pelo botão **↓ XML** na linha, ou
- Marque várias (ou "selecionar todas") e clique em **Baixar N XML** para levar tudo num **.zip**.

### 5) Auditoria

Menu **Auditoria**: histórico de quem confirmou o quê, quando e o protocolo — registro que **não pode ser apagado nem alterado**.

---

## Parar

**Dê dois cliques em "NF-e — Parar".**

- O sistema para, mas **seus dados ficam salvos** (certificados, lotes, auditoria).
- Para usar de novo, é só clicar em **Iniciar**.

---

## ⚠️ Reset — apaga TUDO (use com muito cuidado)

O atalho **"NF-e — RESET (apaga tudo)"** existe só para recomeçar do zero.

- Ele **APAGA de forma permanente**: certificados, lotes, XML baixados, auditoria e o administrador.
- Por segurança, ele **não faz nada** sem você **digitar a palavra `RESETAR`** e teclar Enter.
- Se digitar outra coisa, ele **cancela** e nada é apagado.
- Depois do reset, ao iniciar de novo o sistema pede para **criar um novo administrador**.

> No dia a dia você **nunca** usa o Reset. Para desligar, use sempre **Parar** (que preserva os dados).

---

## Se algo der errado

- **Não abriu o navegador / página não carrega:** o Docker Desktop está verde? Se sim, espere um pouco e atualize a página (F5). Na primeira vez o preparo demora.
- **"Não consegui iniciar":** abra o Docker Desktop, espere o verde e clique em Iniciar de novo.
- **Esqueci a senha do administrador:** sem um reset (que apaga tudo), a recuperação de senha depende de configuração de e-mail (ainda não habilitada). Fale com o suporte técnico.
