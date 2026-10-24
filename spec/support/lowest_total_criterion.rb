# Criterion used only by specs: cheapest total, any number of legs.
# Shows that a new criterion needs no change to the search or to other criteria.
class LowestTotalCriterion < Freight::Criteria::Base
  def name
    "lowest-total"
  end

  def sort_key(route)
    [ route.total_eur, route.leg_count, route.sailing_codes ]
  end

  def prunable?(partial, best)
    partial.total_eur > best.total_eur
  end
end
