// Console NF-e — interações (sem framework). Nenhum segredo é guardado no cliente.
(function () {
  "use strict";
  function ready(fn){ document.readyState !== "loading" ? fn() : document.addEventListener("DOMContentLoaded", fn); }
  var $  = function (s, r){ return (r||document).querySelector(s); };
  var $$ = function (s, r){ return Array.prototype.slice.call((r||document).querySelectorAll(s)); };
  function csrf(){ var m = $('meta[name="csrf-token"]'); return m ? m.content : ""; }
  function setCookie(k,v){ document.cookie = k+"="+v+";path=/;max-age=31536000;samesite=lax"; }

  // ---------- validação (ESPELHO do KeyValidator; backend é autoritativo) ----------
  function dvOk(ch){
    if(!/^\d{44}$/.test(ch)) return false;
    var w=2,s=0; for(var i=42;i>=0;i--){ s+=(+ch[i])*w; w=(w===9)?2:w+1; }
    var r=s%11, dv=r<=1?0:11-r; return dv===(+ch[43]);
  }
  function evaluate(list){
    var seen={}; return list.map(function(raw,idx){
      var d=String(raw).replace(/\D/g,""), valid=true, motivo=null;
      if(d.length!==44){ valid=false; motivo="não tem 44 dígitos"; }
      else if(!dvOk(d)){ valid=false; motivo="dígito verificador inválido"; }
      else if(seen[d]){ valid=false; motivo="duplicada"; }
      else seen[d]=true;
      return { raw:raw, digits:d, valid:valid, motivo:motivo, idx:idx };
    });
  }

  // ---------- toggles tema/densidade ----------
  function initToggles(){
    $$('[data-toggle]').forEach(function(seg){
      var attr = seg.getAttribute("data-toggle"); // theme|density
      var key  = attr === "theme" ? "data-theme" : "data-density";
      var cur  = document.documentElement.getAttribute(key);
      $$('button', seg).forEach(function(b){
        if(b.getAttribute("data-val") === cur) b.classList.add("active");
        b.addEventListener("click", function(){
          var v = b.getAttribute("data-val");
          document.documentElement.setAttribute(key, v);
          setCookie(attr, v);
          $$('button', seg).forEach(function(x){ x.classList.toggle("active", x===b); });
        });
      });
    });
  }

  // ---------- chip input (novo lote) ----------
  function initChips(){
    var box = $("#chips-box"); if(!box) return;
    var input = $("#chip-input"), field = $("#chaves-field"), ph = $("#chips-placeholder");
    var cV = $("#cnt-validas"), cR = $("#cnt-rejeitadas");
    var tokens = [];

    function render(){
      $$(".chip", box).forEach(function(n){ n.remove(); });
      var evs = evaluate(tokens), nv=0, nr=0;
      evs.forEach(function(it){
        it.valid ? nv++ : nr++;
        var chip = document.createElement("span");
        chip.className = "chip " + (it.valid ? "valid" : "invalid");
        var dot = it.valid ? "var(--st-downloaded-dot)" : "var(--st-error-dot)";
        chip.innerHTML = '<span style="width:6px;height:6px;border-radius:50%;background:'+dot+';flex:0 0 auto;"></span>'+
          '<span class="mono">'+(it.digits||it.raw)+'</span>'+
          (it.valid ? "" : '<span style="font-weight:500;">· '+it.motivo+'</span>')+
          '<span class="x" title="Remover">✕</span>';
        chip.querySelector(".x").addEventListener("click", function(){ tokens.splice(it.idx,1); render(); });
        box.insertBefore(chip, input);
      });
      if(cV) cV.textContent = nv;
      if(cR){ cR.textContent = nr; cR.style.color = nr ? "var(--st-error-fg)" : "var(--ink-3)"; }
      if(ph) ph.style.display = tokens.length ? "none" : "block";
      if(field) field.value = evs.filter(function(e){return e.valid;}).map(function(e){return e.digits;}).join("\n");
    }
    function addTokens(text){
      var toks = String(text||"").split(/[\s,;]+/).filter(Boolean);
      if(!toks.length) return;
      tokens = tokens.concat(toks); input.value=""; render();
    }
    input.addEventListener("input", function(e){ if(/[\s,;]/.test(e.target.value)) addTokens(e.target.value); });
    input.addEventListener("keydown", function(e){
      if(e.key==="Enter"||e.key===","){ e.preventDefault(); addTokens(input.value); }
      else if(e.key==="Backspace" && !input.value){ tokens.pop(); render(); }
    });
    input.addEventListener("paste", function(e){ e.preventDefault(); addTokens((e.clipboardData||window.clipboardData).getData("text")); });
    box.addEventListener("click", function(){ input.focus(); });
    var clr = $('[data-action="chips-clear"]'); if(clr) clr.addEventListener("click", function(){ tokens=[]; input.value=""; render(); });
    render();
  }

  // ---------- cadastro de certificado: preview no servidor ----------
  function initCertForm(){
    var form = $("#cert-form"); if(!form) return;
    var file = $("#cert-file"), drop = $("#cert-drop"), lbl = $("#cert-file-label"), result = $("#cert-result");
    if(drop) drop.addEventListener("click", function(){ file.click(); });
    if(file) file.addEventListener("change", function(){ if(lbl) lbl.textContent = file.files[0] ? file.files[0].name : "Clique para selecionar o certificado"; });
    var btn = $('[data-action="cert-preview"]'); if(!btn) return;
    btn.addEventListener("click", function(){
      var fd = new FormData(form);
      btn.disabled = true; btn.textContent = "Lendo…";
      fetch(form.getAttribute("data-preview-url"), { method:"POST", body:fd, headers:{ "X-CSRF-Token":csrf(), "Accept":"application/json" } })
        .then(function(r){ return r.json().then(function(j){ return {ok:r.ok, j:j}; }); })
        .then(function(res){
          btn.disabled=false; btn.textContent="Ler e validar certificado";
          if(res.ok && res.j.ok){
            $("#r-cnpj").textContent=res.j.cnpj; $("#r-razao").textContent=res.j.razao_social;
            $("#r-validade").textContent=res.j.validade; $("#r-fp").textContent=res.j.fingerprint;
            result.style.display="block"; result.scrollIntoView({behavior:"smooth"});
          } else { alert((res.j && res.j.error) || "Falha ao ler o certificado."); }
        })
        .catch(function(){ btn.disabled=false; btn.textContent="Ler e validar certificado"; alert("Erro de rede."); });
    });
  }

  // ---------- relatório: seleção + zip ----------
  function initReport(){
    var all = $('[data-select-all]'); var rows = $$('[data-row-check]');
    var count = $('[data-selected-count]'); var submit = $('[data-zip-submit]');
    if(!rows.length) return;
    function refresh(){
      var n = rows.filter(function(c){return c.checked;}).length;
      if(count) count.textContent = n;
      if(submit){ submit.disabled = n===0; submit.textContent = "↓ Baixar "+n+" XML"; }
      if(all) all.checked = n===rows.length;
    }
    if(all) all.addEventListener("change", function(){ rows.forEach(function(c){ c.checked = all.checked; }); refresh(); });
    rows.forEach(function(c){ c.addEventListener("change", refresh); });
    refresh();
  }

  // ---------- modal step-up ----------
  function initModal(){
    var modal = $("#stepup-modal"); if(!modal) return;
    $$('[data-action="open-modal"]').forEach(function(b){ b.addEventListener("click", function(){ modal.style.display="flex"; var f=$('[data-su-field]',modal); if(f) f.focus(); }); });
    $$('[data-action="close-modal"]').forEach(function(b){ b.addEventListener("click", function(){ modal.style.display="none"; }); });
    modal.addEventListener("click", function(e){ if(e.target===modal) modal.style.display="none"; });
  }

  // ---------- auto-refresh do relatório em processamento ----------
  function initAutoRefresh(){
    var el = $("[data-autorefresh]"); if(!el) return;
    var secs = parseInt(el.getAttribute("data-autorefresh"),10) || 4;
    setTimeout(function(){ location.reload(); }, secs*1000);
  }

  ready(function(){ initToggles(); initChips(); initCertForm(); initReport(); initModal(); initAutoRefresh(); });
})();
