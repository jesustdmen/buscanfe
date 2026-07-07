class CreateAuditEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :audit_events do |t|
      t.string :action, null: false
      t.string :chave
      t.string :c_stat
      t.string :n_prot
      t.text   :detail
      t.references :user,        foreign_key: true, null: true
      t.references :certificado, foreign_key: true, null: true
      t.timestamps
    end
    add_index :audit_events, :created_at
  end
end
