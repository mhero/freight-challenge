require "rails_helper"

RSpec.describe Freight::Criteria do
  describe ".find" do
    it "finds a criterion by name, ignoring case and surrounding spaces" do
      expect(described_class.find("  Cheapest-Direct ")).to be_a(Freight::Criteria::CheapestDirect)
    end

    it "raises for an unknown criterion" do
      expect { described_class.find("cheapest-ever") }.to raise_error(Freight::Errors::UnknownCriterion, /cheapest-ever/)
      expect { described_class.find(nil) }.to raise_error(Freight::Errors::UnknownCriterion)
    end
  end

  describe ".all" do
    it "lists criteria with unique names" do
      names = described_class.all.map(&:name)

      expect(names).to include("cheapest-direct")
      expect(names).to eq(names.uniq)
    end
  end

  describe Freight::Criteria::Base do
    it "makes subclasses implement their own candidates and ranking" do
      criterion = Class.new(described_class).new

      expect { criterion.best_route(build_catalogue([], []), origin: "CNSHA", destination: "NLRTM") }
        .to raise_error(NotImplementedError, /candidate_routes/)
    end

    it "makes subclasses implement their ranking" do
      criterion = Class.new(described_class) do
        private

        def candidate_routes(*) = [ :a_route ]
      end.new

      expect { criterion.best_route(build_catalogue([], []), origin: "CNSHA", destination: "NLRTM") }
        .to raise_error(NotImplementedError, /sort_key/)
    end
  end
end
