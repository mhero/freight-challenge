# A record that was rejected, conflicting or left unpriced during an import.
class ImportIssue < ApplicationRecord
  KINDS = %w[ rejected_record sailing_conflict rate_conflict unpriced orphan_rate ].freeze

  belongs_to :feed_import

  validates :kind, inclusion: { in: KINDS }
  validates :reason, presence: true
end
