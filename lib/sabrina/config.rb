module Sabrina
  # This utility module handles the {Sabrina} configuration. You should not
  # need to deal with it directly, except perhaps for ad-hoc runtime config
  # loading.
  #
  # Each key present in the config can also be called as a module method,
  # for example: +Sabrina::Config.rom_defaults+.
  #
  # Upon the first load of the library, a directory called +.sabrina+ should
  # have been created in your home directory (a level above +My+ +Documents+ in
  # Windows XP, or your Cygwin home if you are running Cygwin). This directory
  # should contain a +sample.json+ config file.
  #
  # Any +.json+ files in the directory except +sample.json+ will be
  # automatically loaded and merged into the default config. Any config file
  # may contain only some of the necessary keys as long as the key hierarchy
  # tree is preserved.
  #
  # The most obvious use of the above would likely be to supply the library with
  # easily distributable config files for specific ROMs.
  #
  # Keep in mind that user config files will not be auto-updated on library
  # updates. New versions might break support for old features or add new ones.
  # If you run into errors, try moving the files away from +.sabrina+ and let
  # the library generate a new sample config, then look at it to see what has
  # changed.
  module Config
    # The user config directory.
    USER_CONFIG_DIR = Dir.home + '/.sabrina/'

    # A sample config file to create. This will not actually be loaded and
    # should not be modified.
    USER_CONFIG_SAMPLE = 'sample.json'

    class << self
      # A simple function for recursive merging of nested hashes.
      #
      # @param [Hash] h1
      # @param [Hash] h2
      # @return [Hash]
      def deep_merge(h1, h2)
        h1.merge(h2) do |_key, x, y|
          x.is_a?(Hash) && y.is_a?(Hash) ? deep_merge(x, y) : y
        end
      end

      # Loads a hash into the internal config.
      #
      # @param [Hash] h the option hash to be merged.
      # @return [0]
      def load(h)
        @sabrina_config ||= {}
        @sabrina_config = deep_merge(@sabrina_config, h)

        @sabrina_config.each_key do |key|
          m = key.downcase.to_sym
          next if respond_to?(m)
          define_singleton_method(m) { @sabrina_config[key] }
        end

        0
      end

      # Creates {USER_CONFIG_DIR}, and {USER_CONFIG_SAMPLE} if the directory
      # is empty.
      #
      # @return [0]
      def create_user_config
        FileUtils.mkpath(USER_CONFIG_DIR) unless Dir.exist?(USER_CONFIG_DIR)

        c = @sabrina_config
        c.delete_if { |key, _val| key.to_s.start_with?('charmap') }

        f = File.new(USER_CONFIG_DIR + USER_CONFIG_SAMPLE, 'w+b')
        f.write(JSON.pretty_generate(c), symbolize_names: true)
        f.close
        0
      end

      # Loads all .json files from {USER_CONFIG_DIR}, exempting
      # {USER_CONFIG_SAMPLE}.
      #
      # @return [0]
      def load_user_config
        files = Dir[USER_CONFIG_DIR + '*.json']

        # create_user_config if files.empty?

        files.each do |x|
          next if x.end_with?(USER_CONFIG_SAMPLE)
          load(JSON.parse(File.read(x)))
        end
        0
      end

      # Returns a hash of all config keys for a ROM type identified by the
      # 4-byte +id+.
      #
      # @param [String] id
      # @return [Hash]
      def rom_params(id)
        defs = @sabrina_config[:rom_defaults]

        params = @sabrina_config[:rom_data].fetch(id.to_sym) do
          fail "Unsupported ROM type: \'#{id}\'."
        end

        defs.merge(params)
      end
    end
  end
end
