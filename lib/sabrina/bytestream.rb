module Sabrina
  # A generic class for dealing with byte data related to a ROM.
  #
  # It is required that +:rom+ and either +:table+ and +:index+ (recommended)
  # or +:offset+ be set in order to enable writing back to a ROM file.
  #
  # There should be no need to use this class directly.
  class Bytestream
    extend ByteInput
    include ByteOutput
    include RomOperations

    # Stores an array of debug strings related to the latest write to ROM.
    #
    # @return [Array]
    # @see RomOperations#write_to_rom
    attr_reader :last_write

    # The ROM being  used for operations.
    #
    # @return [Rom]
    # @see #rom=
    attr_reader :rom

    # The index in the ROM table.
    #
    # @return [Integer]
    # @see #index=
    attr_reader :index

    # The table code to search for data.
    #
    # @return [String or Symbol]
    # @see #table=
    attr_reader :table

    # The directory for saving files. Should be created if specified but not
    # existing.
    #
    # @return [String]
    attr_accessor :work_dir

    # The filename to save to, sans the extension. Subclass +to_file+ methods
    # should take care of adding the right extension.
    #
    # @return [String]
    attr_accessor :filename

    class << self
      # Takes an integer or a "0x"- or "x"-prefixed string and
      # converts it to a valid numerical offset.
      #
      # @param [Integer] p_offset
      # @return [Integer]
      def parse_offset(p_offset)
        o = p_offset.to_s.downcase

        if /[^0-9a-fx]/ =~ o
          fail "\'#{p_offset}\' does not look like a valid offset." \
            ' Supply an integer, or a hex optionally prefixed' \
            " with \'0x\' or \'x\'."
        end

        /[a-fx]/ =~ o ? p_offset.rpartition('x').last.hex : p_offset.to_i
      end
    end

    # Returns a new instance of Bytestream, taking a hash of arguments
    # as the option. The hash may contain the following keys, all of
    # which are optional and init to +nil+ or +false+. Any invalid keys
    # should be ignored.
    #
    # Subclasses should call this method with subclass-specific data.
    # There should be no need to call this method directly.
    #
    # Subclasses should override the +load_settings(h)+ private method
    # to allow for additional options.
    #
    # @param [Hash] h
    # @option h [Object] :representation The internal representation
    #   of the byte data. Subclasses should be able to convert bytes
    #   to and from the representation via the {ByteOutput#present} and
    #   {ByteOutput#generate_bytes} methods.
    # @option h [Boolean] :pointer_mode Whether to expect pointers in the
    #   table instead of actual data. This voids +:index_length+.
    # @option h [Boolean] :force_overwrite Whether to always overwrite in place,
    #   even if table says otherwise.
    # @option h [Boolean] :lz77 Whether to read and write ROM data as
    #   {Lz77}-compressed.
    # @option h [Boolean] :is_gba_string Whether to read ROM data as
    #   a GBA-encoded, 0xFF-terminated string.
    # @option h [Rom] :rom A ROM to be used for reading and writing data.
    # @option h [Symbol, String] :table The table to read offset data from.
    #   This should be the name of an option specified in the +rom_data+ hash.
    #   +:table+ and +:index+ will take precedence over +:offset+ if present.
    #   This is the recommended way of dealing with monster data,
    #   as it will allow automagically updating the offset upon writing
    #   or switching ROMs.
    # @option h [Integer] :index The index to read from the table.
    #   See {#index=} for details.
    # @option h [Integer] :index_length The length of a single table
    #   entry, necessary for seeking.
    # @option h [Integer] :offset The position in ROM to read and write to.
    #   This will only be used if +:table+ or +:index+ are not present.
    #   See {Bytestream.parse_offset} for details.
    # @option h [Integer] :length The byte length to read from the ROM.
    #   This will be ignored if +:lz77+ compression is enabled.
    def initialize(h = {})
      # Subclasses may want to override defaults, hence ||=
      @work_dir ||= nil
      @filename ||= nil

      @representation ||= nil
      @bytes_cache ||= nil
      @lz77_cache ||= nil
      @length_cache ||= nil

      @last_write ||= nil

      @old_offset ||= nil
      @old_length ||= nil

      @force_overwrite ||= false

      @lz77 ||= false
      @is_gba_string ||= false

      @rom ||= nil
      @table ||= nil
      @index ||= nil
      @offset ||= nil
      @length ||= nil

      @pointer_mode ||= false
      @index_length ||= nil

      load_settings(h)
      present
    end

    # Returns the associated offset, first trying the table and then +:offset+.
    # Returns +nil+ if neither has sufficient data.
    #
    # @return [Integer]
    def offset
      if @rom && @table && @index
        return @rom.read_offset_from_table(@table, @index) if @pointer_mode
        return @rom.table_to_offset(@table, @index, @index_length)
      end
      @offset
    end

    # Returns the offset as a reversed byte string.
    # This is the format used internally by ROMs to reference data.
    #
    # @return [String]
    def pointer
      Rom.offset_to_pointer(offset)
    end

    # Sets the index under which to search for data in the +:table+.
    # Compared to setting :index=>index in the options hash, this will
    # assume the index is
    #
    # This will clear the internal cache.
    #
    # @param [Integer] p_index For monsters, this should be the
    #   real index (accounting for blank spaces between
    #   dex numbers 251 and 252) of the monster you want to act on.
    #   Ideally, a wrapper object should calculate this for you.
    # @return [self]
    def index=(p_index)
      @index = p_index
      clear_cache
      @index
    end

    # Sets the ROM with which the byte data is to be associated.
    # This is the same as setting +:rom+ in the options hash.
    #
    # This will clear the internal cache.
    #
    # @param [Rom] p_rom
    # @return [Rom] new rom.
    def rom=(p_rom)
      @rom = p_rom
      clear_cache(lz77: false)
      @rom
    end

    # Sets the table name identifier and optionally the index.
    # The table identifier should be a key in +rom_data+ config.
    #
    # This is the same as setting +:table+, +:index+
    # in the options hash.
    #
    # This will clear the internal cache.
    #
    # @param [String, Symbol] p_table
    # @param [Integer] p_index see {#index=} for details.
    # @return [self]
    def table=(p_table, p_index = nil)
      @table = p_table
      @index = p_index if p_index
      clear_cache
      [@table, @index]
    end

    # Sets the offset of the data in +:rom+.
    # This is the same as setting +:offset+ in the options hash.
    #
    # This will clear the internal cache.
    #
    # @param [Integer, String] p_offset See {Bytestream.parse_offset} for details.
    # @return [Integer] new offset.
    def offset=(p_offset)
      return self if p_offset == @offset
      @old_offset = @offset
      @offset = Bytestream.parse_offset(p_offset)
      clear_cache
      @offset
    end

    private

    # Loads a hash of options. Subclasses should override this to allow
    # additional options.
    #
    # @param [Hash] h see {#initialize}.
    # @return [self]
    def load_settings(h)
      @representation = h.fetch(:representation, @representation)
      @bytes_cache = h.fetch(:bytes_cache, @bytes_cache)

      @force_overwrite = h.fetch(:force_overwrite, @force_overwrite || false)

      @lz77 = h.fetch(:lz77, @lz77 || false)
      @is_gba_string = h.fetch(:is_gba_string, @is_gba_string)
      @old_length = h.fetch(:old_length, @old_length)

      @rom = h.fetch(:rom, @rom)
      @offset = Bytestream.parse_offset(h[:offset]) if h.key?(:offset)
      @length = h.fetch(:length, @length)

      @table = h.fetch(:table, @table)
      @index = h.fetch(:index, @index)

      @pointer_mode = h.fetch(:pointer_mode, @pointer_mode)
      @index_length = h.fetch(:index_length, @index_length)
      self
    end
  end
end
