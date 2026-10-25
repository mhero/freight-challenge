module Freight
  # Binary min-heap. Entries are (key, value) pairs ordered by key with <=>.
  class MinHeap
    def initialize
      @items = []
    end

    def empty?
      @items.empty?
    end

    def size
      @items.size
    end

    def push(key, value)
      @items << [ key, value ]
      sift_up(@items.size - 1)
      self
    end

    # Removes and returns the value with the smallest key, nil when empty.
    def pop
      return nil if empty?

      top = @items.first
      last = @items.pop
      unless @items.empty?
        @items[0] = last
        sift_down(0)
      end
      top.last
    end

    private

    def sift_up(index)
      while index.positive?
        parent = (index - 1) / 2
        break if (@items[parent].first <=> @items[index].first) <= 0

        @items[parent], @items[index] = @items[index], @items[parent]
        index = parent
      end
    end

    def sift_down(index)
      loop do
        smallest = index
        [ 2 * index + 1, 2 * index + 2 ].each do |child|
          smallest = child if child < size && (@items[child].first <=> @items[smallest].first).negative?
        end
        break if smallest == index

        @items[smallest], @items[index] = @items[index], @items[smallest]
        index = smallest
      end
    end
  end
end
