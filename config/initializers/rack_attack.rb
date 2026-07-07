# Rate-limit de login (por IP e por conta) + throttle geral — defesa a credential stuffing.
class Rack::Attack
  # Login por IP: 10/min
  throttle("login/ip", limit: 10, period: 60) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  # Login por conta (email): 5/min
  throttle("login/email", limit: 5, period: 60) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.params.dig("user", "email").to_s.downcase.strip.presence
    end
  end

  # Step-up (re-passphrase): 5/min por IP
  throttle("stepup/ip", limit: 5, period: 60) do |req|
    req.ip if req.path == "/step_up" && req.post?
  end

  # Piso geral por IP
  throttle("req/ip", limit: 300, period: 300) { |req| req.ip }

  self.throttled_responder = lambda do |_req|
    [429, { "Content-Type" => "text/plain" }, ["Muitas tentativas. Aguarde e tente novamente.\n"]]
  end
end

Rails.application.config.middleware.use Rack::Attack
