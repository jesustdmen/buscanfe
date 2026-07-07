class CreateLotes < ActiveRecord::Migration[7.2]
  def change
    create_table :lotes do |t|
      t.references :certificado, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string  :status, null: false, default: "open"
      t.string  :tp_amb, null: false, default: "1" # produção
      t.timestamps
    end
  end
end
