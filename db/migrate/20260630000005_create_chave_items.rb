class CreateChaveItems < ActiveRecord::Migration[7.2]
  def change
    create_table :chave_items do |t|
      t.references :lote, null: false, foreign_key: true
      t.string  :chave, null: false, limit: 44
      t.string  :status, null: false, default: "pending"
      t.string  :c_stat_evento
      t.string  :n_prot
      t.string  :c_stat_download
      t.string  :tipo
      t.string  :xml_path
      t.text    :error
      t.integer :attempts, null: false, default: 0
      t.timestamps
    end
    add_index :chave_items, [:lote_id, :chave], unique: true # dedup dentro do lote
    add_index :chave_items, :status
  end
end
