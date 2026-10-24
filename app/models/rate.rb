class Rate < ApplicationRecord
  belongs_to :sailing
  belongs_to :import, class_name: "FeedImport"

  validates :amount, :currency, presence: true
end
