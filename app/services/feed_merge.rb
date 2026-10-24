# Applies the merge rules to one parsed feed. Pure Ruby: the caller supplies the
# exchange rates and persists the result.
class FeedMerge
  Issue = Data.define(:kind, :reference, :reason, :details)
  Result = Data.define(:sailings, :resolutions, :issues)

  def initialize(exchange_rates)
    @resolver = Freight::RateResolver.new(exchange_rates)
  end

  def call(sailing_records:, rate_records:)
    consolidated = Freight::SailingConsolidator.call(sailing_records)
    candidates = rate_records.group_by(&:sailing_code).transform_values { |records| records.map(&:rate) }

    issues = conflict_issues(consolidated.conflicts)
    issues.concat(orphan_issues(candidates, consolidated))

    resolutions = {}
    consolidated.sailings.each do |sailing|
      resolution = @resolver.resolve(departure_date: sailing.departure_date, candidates: candidates.fetch(sailing.code, []))
      resolutions[sailing.code] = resolution
      issues.concat(rate_issues(sailing, resolution))
    end

    Result.new(sailings: consolidated.sailings, resolutions: resolutions, issues: issues)
  end

  private

  def conflict_issues(conflicts)
    conflicts.map do |code, variants|
      Issue.new(
        kind: "sailing_conflict", reference: code,
        reason: "same sailing_code with different route or dates, sailing excluded",
        details: { "variants" => variants.map { |variant| variant.to_h.transform_values(&:to_s) } }
      )
    end
  end

  def orphan_issues(candidates, consolidated)
    known = consolidated.sailings.map(&:code) + consolidated.conflicts.keys
    (candidates.keys - known).map do |code|
      Issue.new(kind: "orphan_rate", reference: code, reason: "rate for a sailing that is not in the feed",
                details: { "rates" => candidates[code].map { |rate| describe(rate) } })
    end
  end

  def rate_issues(sailing, resolution)
    if resolution.conflict
      [ Issue.new(
        kind: "rate_conflict", reference: sailing.code,
        reason: resolution.priced? ? "conflicting rates, kept the highest in EUR" : "conflicting rates, #{resolution.unpriced_reason}",
        details: { "kept" => (describe(resolution.rate) if resolution.priced?), "discarded" => resolution.discarded.map { |rate| describe(rate) } }
      ) ]
    elsif !resolution.priced?
      [ Issue.new(kind: "unpriced", reference: sailing.code, reason: resolution.unpriced_reason, details: {}) ]
    else
      []
    end
  end

  def describe(rate)
    { "amount" => rate.amount_text, "currency" => rate.currency }
  end
end
