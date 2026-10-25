module Freight
  # A search hit its resource limit (statement timeout). No route is returned:
  # a partial or best-so-far answer would not be the optimal one.
  class SearchTimeout < Error; end
end
