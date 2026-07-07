class CreateCertificados < ActiveRecord::Migration[7.2]
  def change
    create_table :certificados do |t|
      t.string   :rotulo,       null: false   # único campo digitado
      t.string   :cnpj                          # derivados do cert
      t.string   :razao_social
      t.datetime :validade
      t.string   :fingerprint
      t.text     :senha         # cifrado (AR Encryption)
      t.text     :pfx_data      # cifrado (Base64(DER))
      t.timestamps
    end
    add_index :certificados, :rotulo,      unique: true
    add_index :certificados, :fingerprint, unique: true
  end
end
