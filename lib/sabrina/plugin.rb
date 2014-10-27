module Sabrina
  # This is the recommended wrapper namespace for {Plugin Plugins} that enhance
  # {Sabrina} with new functionality.
  #
  # @see Plugin
  module Plugins; end

  # The base class for plugins that improve classes with the ability
  # to handle additional data. The +#initialize+ method of the target
  # class should contain a call to +load_plugins+.
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
  # The base Plugin class makes some assumptions about how certain features
  # might be implemented in subclasses, this might speed up development
  # of plugins. Refer to {#write}, {#save} and {#load} for details or override
  # those methods with your own versions inside subclasses.
  #
  # For clarity, plugins should be contained within the {Plugins}
  # namespace.
  class Plugin
    include Inspector

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
    # @param [Object] monster
    # @return [Plugin]
    def initialize(monster)
      @monster = monster
      @rom = monster.rom
      @index = monster.index

      reread
    end

    # Returns an array of child Bytestream objects.
    #
    # @return [Array]
    def children
      []
    end

    # Drop internal data and force reloading from ROM.
    #
    # @return [self]
    def reread(*_args)
      children.map(&:reload_from_rom)

      self
    end

    # Write data to ROM.
    #
    # @return [Array] Any return data from child methods.
    def write(*_args)
      children.map(&:write_to_rom)
    end

    # Save data to a file.
    def save(file = @monster.filename, dir = @monster.work_dir, *_args)
      target = get_path(file, dir, mkdir: true)

      "#{ target[:file] } (#{ File.binwrite(target[:path], to_file) })"
    end

    # Load data from a file.
    def load(file = @monster.filename, dir = @monster.work_dir, *_args)
      path = get_path(file, dir)[:path]

      load_hash(JSON.parse(File.read(path), symbolize_names: true))
    end

    # Loads a hash representation of the data. If present, nested hashes
    # under a key equivalent to {SHORT_NAME} or own index will be loaded.
    #
    # @param [Hash] hash
    # @return [self]
    def load_hash(hash)
      hash.to_a
      self
    end

    # Returns a pretty JSON representation of the data.
    #
    # @return [String]
    def to_json
      respond_to?(:to_hash) ? JSON.pretty_generate(to_hash) : nil
    end

    # Returns a file representation of the data.
    def to_file
      to_json
    end

    # Subclasses should override this to provide a useful textual
    # representation of instance data.
    # @return [String]
    def to_s
      "<#{self.class.plugin_name}>"
    end

    # Whether a plugin instance supports a feature.
    #
    # @return [Boolean]
    def feature?(f)
      self.class.features.include?(f)
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

      suffix = self.class::SUFFIX

      FileUtils.mkpath(d) if h.fetch(:mkdir, false) && !Dir.exist?(d)

      f << suffix unless f.downcase.end_with?(suffix)
      {
        path: d << f,
        file: f
      }
    end
  end
end
