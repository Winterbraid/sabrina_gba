module Sabrina
  # This is the recommended wrapper namespace for {Plugin Plugins} that enhance
  # {Sabrina} with new functionality.
  #
  # @see Plugin
  module Plugins; end

  # The base class for plugins that improve classes with the ability
  # to handle additional data. The +#initialize+ method for every
  # plugin should accept a target class instance as the parameter.
  # The +#initialize+ method of the target class should contain
  # a call to +load_plugins+.
  #
  # When a class has been enhanced by a plugin, it will gain a read-only
  # attribute +#plugins+ that will contain a set of all plugins registered
  # with that class. Class instances will gain a read-only attribute
  # +#plugins+ that will contain a hash of SHORT_NAME => (plugin instance)
  # pairs.
  #
  # Each plugin will also expose a set of {FEATURES}. For every +feature+, two
  # instance methods will be added to the target object: +#feature+, which
  # will call +#feature+ on every plugin instance that supports it, and
  # +#feature_shortname+, which will call +#feature+ on the instance of the
  # plugin identified by {SHORT_NAME} (assuming it supports that feature).
  #
  # For clarity, plugins should be contained within the {Plugins}
  # namespace.
  class Plugin
    # What class this plugin enhances. This should be required before
    # the plugin.
    #
    # The target class should have +load_plugins+ at the end of the init.
    ENHANCES = Monster

    # Plugin name goes here.
    PLUGIN_NAME = 'Generic Plugin'

    # Short name should contain only a-z, 0-9, and underscores.
    # This will be the suffix for target instance methods.
    SHORT_NAME = 'genericplugin'

    # Tells the enhanced class what public instance methods the plugin
    # should expose.
    #
    # This should be a set of symbols.
    #
    # Common features include +:reread+, +:write+, +:save+, +:load+.
    FEATURES = Set.new [:reread, :write, :save, :load]

    # The suffix for saving files.
    SUFFIX = '.dat'

    class << self
      # @see PLUGIN_NAME
      def plugin_name
        self::PLUGIN_NAME
      end

      # @see ENHANCES
      def target
        self::ENHANCES
      end

      # @see SHORT_NAME
      def short_name
        self::SHORT_NAME.downcase.gsub(/[^a-z0-9_]/, '')
      end

      # @see FEATURES
      def features
        self::FEATURES
      end

      # Automagically registers new plugins with target.
      def inherited(subclass)
        target.extend(Plugin::Register)
        Plugin::Load.include_in(target)

        target.register_plugin(subclass)
        super
      end

      # Generate a +#feature+ method.
      #
      # @param [Symbol] f feature.
      # @return [Proc]
      def feature_all(f)
        proc do |*args|
          targets = @plugins.select { |_key, val| val.feature?(f) }
          targets.values.map { |val| val.method(f).call(*args) }
        end
      end

      # Generate a +#feature_shortname+ method.
      #
      # @param [Symbol] f feature.
      # @return [Proc]
      def feature_this(f, n)
        proc do |*args|
          @plugins.fetch(n).method(f).call(*args)
        end
      end

      # Provides a short description of the plugin's functionality.
      #
      # @return [String]
      def to_s
        "\'#{short_name}\': enhances #{target.name}, supports #{features.to_a}"
      end
    end

    # Generates a new {Plugin} object.
    #
    # @param [Object] parent
    # @return [Plugin]
    def initialize(parent, *_args)
      @parent = parent
    end

    # Drop internal data and force reloading from ROM.
    #
    # @return [Array] Any return data from child methods.
    def reread(*_args)
      children.map(&:reload_from_rom)
    end

    # Write data to ROM.
    #
    # @return [Array] Any return data from child methods.
    def write(*_args)
      children.map(&:write_to_rom)
    end

    # Whether a plugin instance supports a feature.
    #
    # @return [Boolean]
    def feature?(f)
      self.class.features.include?(f)
    end

    # Subclasses should override this to provide a useful textual
    # representation of instance data.
    # @return [String]
    def to_s
      "<#{self.class.plugin_name}>"
    end

    private

    # Concatenate the file name and directory into a full path, optionally
    # creating the directory if it doesn't exist.
    #
    # @param [String] file
    # @param [String] dir
    # @param [Hash] h
    #   @option h [Boolean] :mkdir If +true+, create +dir+ if it doesn't
    #     exist.
    # @return [String]
    def get_path(file, dir, h = {})
      f, d = file.dup, dir.dup
      d << '/' unless d.empty? || d.end_with?('/')

      FileUtils.mkpath(d) if h.fetch(:mkdir, false) && !Dir.exist?(d)

      path = d << f
      path << self::SUFFIX unless path.downcase.end_with?(self::SUFFIX)
    end
  end
end
