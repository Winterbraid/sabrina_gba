module Sabrina
  # Provides an +#inspect+ method that behaves more like what 1.9.x used to do.
  # This is mainly for saner behaviour in new versions of IRB, Pry etc.
  module Inspector
    # Stores the original +#inspect+ method.
    #
    # @return [String]
    alias_method :long_inspect, :inspect

    # Inspect defaults to +#to_s+ if present, otherwise uses the previously
    # defined method.
    #
    # @return [String]
    def inspect
      respond_to?(:to_s) ? to_s : long_inspect
    end
  end
end
