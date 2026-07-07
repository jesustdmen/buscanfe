# Cookie de sessão endurecido: HttpOnly (padrão), SameSite=Lax, Secure em produção.
Rails.application.config.session_store :cookie_store,
  key: "_nfe_registro_session",
  same_site: :lax,
  secure: Rails.env.production?,
  httponly: true
