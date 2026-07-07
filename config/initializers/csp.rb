# Content-Security-Policy (defesa a XSS/clickjacking). script-src :self bloqueia JS injetado.
# style/font liberam Google Fonts (Inter + JetBrains Mono) do design.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.script_src      :self
    policy.style_src       :self, :unsafe_inline, "https://fonts.googleapis.com"
    policy.font_src        :self, "https://fonts.gstatic.com"
    policy.connect_src     :self
    policy.img_src         :self, :data
    policy.object_src      :none
    policy.base_uri        :self
    policy.form_action     :self
    policy.frame_ancestors :none
  end
end
