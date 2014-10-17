module Sabrina
  # An abstract class for dealing with further abstractions of data related
  # to a specific, numbered monster.
  #
  # See {Sabrina::Plugins} for extensions that might enhance this class
  # with added functionality.
  class Monster
    include ChildrenManager

    # @!attribute [rw] rom
    #   The current working ROM file.
    #   @return [Rom]
    # @!attribute [rw] index
    #   The real index of the monster.
    #   @return [Integer]
    attr_children :rom, :index

    # The filename for saving data to a file, sans the path and extension.
    # Refer to {#work_dir=} for setting the path, and child +#save+
    # methods should take care of adding the right extension.
    #
    # @return [String]
    attr_reader :filename

    # The directory for reading and saving file data.
    # Defaults to the current ROM's file name affixed with +_files+.
    #
    # @return [String]
    # @see #work_dir=
    attr_reader :work_dir

    # The effective dex number of the monster, depending on any blanks
    # in the ROM file.
    attr_reader :dex_number

    class << self
      # Calculates the real index by parsing the provided index either
      # as a dex number (when integer) or as a string. A number string
      # prefixed with an exclamation mark +"!"+ will be interpreted as
      # the real index.
      #
      # @param [Integer, String] index either the dex number, or the
      #   real index prepended with "!".
      # @param [Rom] rom the rom file to pull the dex data from.
      # @return [Integer] the real index of the monster in the ROM file,
      #   after accounting for blank spaces between dex numbers 251 and 252.
      def parse_index(index, rom)
        in_index = index.to_s
        if /[^0-9\!]/ =~ in_index
          fail "\'#{in_index}\' does not look like a valid index."
        end

        out_index =
          if in_index['!']
            in_index.rpartition('!').last.to_i
          else
            i = in_index.to_i
            i < rom.dex_blank_start ? i : i + rom.dex_blank_length
          end

        unless out_index < rom.dex_length
          fail "Real index #{out_index} out of bounds;" \
            " #{rom.id} has #{rom.dex_length} monsters."
        end

        out_index
      end
    end

    # Generates a new instance of Monster.
    #
    # @param [Rom] rom the ROM to be associated with the monster.
    # @param [Integer] index either the dex number of the monster,
    #   or the real (ROM) index prefixed with "!". See {parse_index}
    #   for details.
    # @param [String] dir the working directory.
    # @return [Monster]
    def initialize(rom, index, dir = nil)
      @plugins = {}

      @rom = rom
      @index = self.class.parse_index(index, @rom)
      @dex_number = index

      @filename = format('%03d', @index)
      @work_dir = dir || @rom.filename.dup << '_files/'

      load_plugins
    end

    # @return [Array]
    # @see ChildrenManager
    def children
      @plugins.values
    end

    # Sets the path for saving data to a file.
    #
    # @param [String] path
    # @return [String]
    def work_dir=(path)
      path << '/' unless path.end_with?('/')
      @work_dir = path
    end

    alias_method :dir=, :work_dir=

    # Sets the dex number of the monster, dependent on any blanks in the ROM.
    #
    # @return [Integer]
    # @see parse_index
    def dex_number=(n)
      @dex_number = n
      self.index = self.class.parse_index(n, @rom)
    end

    # Reads the monster name from the ROM.
    #
    # @return [String]
    def name
      @rom.monster_name(@index)
    end

    # Closes the ROM file.
    #
    # @return [0]
    def close
      @rom.close
      0
    end

    # Prints a blurb consisting of the monster's dex number and name.
    #
    # @return [String]
    def to_s
      "#{@index}. #{name}"
    end
  end
end
