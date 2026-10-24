module Freight
  # Identical duplicate records collapse into one. Records that share a sailing
  # code but differ in route or dates are a conflict: the sailing is excluded.
  class SailingConsolidator
    Result = Data.define(:sailings, :conflicts)

    def self.call(records)
      sailings = []
      conflicts = {}
      records.group_by(&:code).each do |code, group|
        variants = group.uniq
        if variants.one?
          sailings << variants.first
        else
          conflicts[code] = variants
        end
      end
      Result.new(sailings: sailings, conflicts: conflicts)
    end
  end
end
