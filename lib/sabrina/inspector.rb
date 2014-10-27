module Sabrina
  module Inspector
    alias_method :long_inspect, :inspect

    # Changes inspect behaviour to be closer to 1.9.x (and look saner in IRB).
    #
    # @return [String]
    def inspect
      respond_to?(:to_s) ? to_s : long_inspect
    end
  end
end