class User < ApplicationRecord
  validates :name, presence: true

  def self.create_user(name)
    User.create(name: name)
  end
end

User.create_user("test")
