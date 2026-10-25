require "rails_helper"

RSpec.describe Freight::MinHeap do
  subject(:heap) { described_class.new }

  it "returns values in key order" do
    [ 5, 1, 4, 2, 3, 9, 0 ].each { |key| heap.push([ key ], "v#{key}") }

    popped = Array.new(7) { heap.pop }

    expect(popped).to eq(%w[ v0 v1 v2 v3 v4 v5 v9 ])
    expect(heap).to be_empty
  end

  it "orders array keys element by element and tolerates equal keys" do
    heap.push([ 1, "b" ], :b).push([ 1, "a" ], :a).push([ 0, "z" ], :z).push([ 1, "a" ], :a2)

    expect(heap.size).to eq(4)
    expect([ heap.pop, heap.pop ]).to eq(%i[ z a ]).or eq(%i[ z a2 ])
    expect(%i[ a a2 ]).to include(heap.pop)
    expect(heap.pop).to eq(:b)
  end

  it "returns nil when empty" do
    expect(heap.pop).to be_nil
  end

  it "matches a sort on random keys" do
    rng = Random.new(7)
    keys = Array.new(200) { [ rng.rand(0..20), rng.rand(0..5) ] }
    keys.each { |key| heap.push(key, key) }

    expect(Array.new(200) { heap.pop }).to eq(keys.sort)
  end
end
