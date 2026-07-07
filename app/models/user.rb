class User < ApplicationRecord
  # Auth nativa (Devise). Sem registro público (usuários criados por admin/seed).
  devise :database_authenticatable, :recoverable, :rememberable, :validatable,
         :lockable, :timeoutable
end
