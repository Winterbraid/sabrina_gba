module Sabrina
  class Plugin
    # Allows to load plugins. Add +load_plugins+ at the end of your class's
    # +initialize+ call.
    module Load
      class << self
        # Exposes +#append_features+.
        def include_in(obj)
          append_features(obj) unless obj.include?(self)
        end
      end

      attr_reader :plugins

      private

      # Generates plugin instances. This should be called from
      # the target class's init.
      #
      # @return [0]
      def load_plugins
        self.class.plugins.each do |plugin|
          n = plugin.short_name

          plugin.features.each do |f|
            feature_all_sym = f.to_sym
            feature_this_sym = "#{f}_#{n}"
            unless respond_to?(feature_all_sym)
              define_singleton_method(feature_all_sym, plugin.feature_all(f))
            end
            unless respond_to?(feature_this_sym)
              define_singleton_method(feature_this_sym, plugin.feature_this(f, n))
            end
          end

          define_singleton_method(n, -> { @plugins[n] }) unless respond_to?(n)
          @plugins[n] = plugin.new(self)
        end
        0
      end
    end
  end
end
