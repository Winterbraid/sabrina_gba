module Sabrina
  class Plugin
    # Allows to register plugins.
    module Register
      # Lists all currently registered plugins.
      #
      # @return [Set]
      def plugins
        @plugins.to_a
      end

      # Registers a new plugin for handling a specific subset of monster
      # data.
      #
      # @return [0]
      # @see Plugin
      def register_plugin(plugin)
        @plugins ||= Set.new
        @plugins << plugin
      end

      # Lists all currently available features.
      #
      # @return [Set]
      def features
        s = Set.new
        @plugins.each { |x| s += x.features }
        s
      end
    end
  end
end
