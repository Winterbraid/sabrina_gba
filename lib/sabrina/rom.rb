module Sabrina
  # A class for handling low-level read and write operations upon a ROM file.
  # Beyond creating a new {Rom} from filename for passing to
  # {Bytestream}-family objects, you should not need to deal with it
  # or any of its methods directly.
  class Rom
    # The position in the ROM file from which to read the 4-byte
    # identifier string. This is relied upon to pull the ROM type
    # data from the {Config}.
    ID_OFFSET = 172

    # The 4-byte ID of the ROM.
    #
    # @return [String]
    # @see Config.rom_params
    attr_reader :id

    # The full path and filename of the ROM file.
    #
    # @return [String]
    attr_reader :path

    # Just the filename of the ROM file.
    #
    # @return [String]
    attr_reader :filename

    # The ROM file object.
    #
    # @return [File]
    attr_reader :file

    class << self
      # Converts a numerical offset to a GBA-compliant,
      # reverse 3-byte pointer.
      #
      # @return [Integer]
      def offset_to_pointer(offset)
        format('%06X', offset).scan(/../).reverse.map { |x| x.hex.chr }.join('')
      end

      # Converts a reverse 3-byte pointer to a numerical offset.
      #
      # @return [Integer]
      def pointer_to_offset(pointer)
        Bytestream.from_bytes(pointer.reverse).to_i
      end
    end

    # Creates a new Rom object from the supplied ROM image file.
    #
    # @return [Rom]
    def initialize(rom_file)
      @path = rom_file
      @file = File.new(rom_file, 'r+b')

      @filename = @path.rpartition('/').last.rpartition('.').first
      @id = load_id

      @params = Config.rom_params(@id)

      @params.each_key do |key|
        m = key.downcase.to_sym
        define_singleton_method(m) { @params[key] } unless respond_to?(m)
      end
    end

    # Returns the numerical offset associated with the +name+ in the
    # current ROM {Config} data.
    #
    # @param [String, Symbol] name
    # @return [Integer]
    def table(name)
      Bytestream.parse_offset(param(name))
    end

    # Fetches a specific key from the ROM {Config} data.
    #
    # @param [String, Symbol] p the key to look for.
    # @see Config
    def param(p)
      s = p.to_sym
      @params.fetch(s) { fail "No parameter #{s} for ROM type #{@id}." }
    end

    # Gets the name of the monster identified by +real_index+ from
    # the ROM file.
    #
    # @param [Integer] real_index
    # @return [String]
    # @see Monster.parse_index
    def monster_name(real_index)
      read_string_from_table(:name_table, real_index, name_length)
    end

    # Takes a table name and index and returns a byte offset.
    #
    # @param [String, Symbol] name the name of the table as specified
    #   in the ROM {Config} data.
    # @param [Integer] index in the case of a monster, the real index
    #   of the monster.
    # @param [Integer] index_length The number of bytes occupied by each
    #   index in +table+. If absent, will search {Config} for a +_length+
    #   param associated with the table.
    # @return [String]
    def table_to_offset(name, index, index_length = nil)
      index_length ||= param(name.to_s.sub('_table', '_length'))

      table(name) + index * index_length
    end

    # Reads a numerical offset associated with +index+ from the table
    # +name+. This assumes the table contains 3-byte GBA pointers.
    #
    # @param [String, Symbol] name the name of the table as specified
    #   in the ROM {Config} data.
    # @param [Integer] index in the case of a monster, the real index
    #   of the monster.
    # @param [Integer] length the length of a single entry.
    # @return [Integer]
    # @see offset_to_pointer
    def read_offset_from_table(name, index, length = 8)
      pointer = read_table(name, index, length, 3)
      self.class.pointer_to_offset(pointer)
    end

    # Reads a stream expected to be an 0xFF-terminated GBA string from the
    # table. This assumes the entries before +index+ are each +index_length+
    # long.
    #
    # @param [String, Symbol] name the name of the table as specified
    #   in the ROM {Config} data.
    # @param [Integer] index in the case of a monster, the real index
    #   of the monster.
    # @param [Integer] index_length The number of bytes occupied by each
    #   index in +table+. If absent, will search {Config} for a +_length+
    #   param associated with the table.
    # @return [String]
    # @see GBAString
    def read_string_from_table(name, index, index_length = nil)
      index_length ||= param(name.to_s.sub('_table', '_length'))
      s = read_string(table(name) + index * index_length)
      GBAString.from_bytes(s).to_s
    end

    # Reads +length+ bytes of data from the table. This assumes the
    # entries before +index+ are each +index_length+ long.
    #
    # @param [String, Symbol] name the name of the table as specified
    #   in the ROM {Config} data.
    # @param [Integer] index in the case of a monster, the real index
    #   of the monster.
    # @param [Integer] index_length The number of bytes occupied by each
    #   index in +table+. If absent, will search {Config} for a +_length+
    #   param associated with the table.
    # @param [Integer] length how many bytes to read. Will assume +index_length+
    #   if absent.
    # @return [String]
    # @see Bytestream
    def read_table(name, index, index_length = nil, length = nil)
      index_length ||= param(name.to_s.sub('_table', '_length'))
      length ||= index_length
      read(table(name) + index * index_length, length)
    end

    # Reads the data from +offset+, assuming it to be {Lz77}-compressed.
    #
    # @param [Integer] offset
    # @return [Hash] contains the uncompressed data as +:stream+ and the
    #   estimated original compressed length as +:original_length+.
    # @see Lz77.uncompress
    def read_lz77(offset)
      Lz77.uncompress(self, offset)
    end

    # Reads a stream expected to be a 0xFF-terminated GBA string from +offset+.
    #
    # @param [Integer] offset
    # @return [String]
    # @see GBAString
    def read_string(offset)
      read_until(offset, "\xFF")
    end

    # Reads bytes from a position in a table, expecting the data to end in
    # +terminator+.
    #
    # @param [String, Symbol] name the name of the table as specified
    #   in the ROM {Config} data.
    # @param [Integer] index in the case of a monster, the real index
    #   of the monster.
    # @param [Integer] index_length The number of bytes occupied by each
    #   index in +table+. If absent, will search {Config} for a +_length+
    #   param associated with the table.
    # @param [String] terminator
    # @return [String]
    # @see GBAString
    def read_table_until(name, index, index_length = nil, terminator)
      offset = read_offset_from_table(name, index, index_length)
      read_until(offset, terminator)
    end

    # Reads bytes from +offset+ until +terminator+.
    #
    # @param [Integer] offset
    # @param [String] terminator
    # @return [String]
    # @see GBAString
    def read_until(offset, terminator)
      term = terminator.force_encoding('ASCII-8BIT')

      @file.seek(offset)
      @file.gets(term)
    end

    # Reads +length+ bytes from +offset+, or the entire rest of the file
    # if +length+ is not specified.
    #
    # @param [Integer] offset
    # @param [Integer] length
    # @return [String]
    def read(offset, length = nil)
      @file.seek(offset)
      length ? @file.read(length) : @file.read
    end

    # Returns the position of the first occurence of +length+ 0xFF
    # bytes, assumed to be free space available for writing.
    # If +start+ is +nil+, the search will begin at the +:free_space_start+
    # offset specified in the ROM {Config}.
    #
    # @param [Integer] length
    # @return [Integer] the first found offset.
    def find_free(length, start = nil)
      query = ("\xFF" * length).force_encoding('ASCII-8BIT')
      start ||= Bytestream.parse_offset(free_space_start)

      @file.seek(start)
      match = start + @file.read.index(query)

      return match if match % 4 == 0 || !match

      match += 1 until match % 4 == 0
      find_free(length, match)
    end

    # Writes a stream of bytes at the provided offset.
    #
    # @param [Integer] offset
    # @return [String] a debug message.
    def write(offset, b)
      @file.seek(offset)
      @file.write(b.force_encoding('ASCII-8BIT'))

      "Rom#write: Wrote #{b.length} bytes at #{offset}" \
        " (#{ format('%06X', offset) })."
    end

    # Writes the +offset+ associated with +index+ to the table
    # +name+. This assumes the table contains 3-byte GBA pointers.
    #
    # @param [Integer] offset the offset. It will be converted to a
    #   GBA-compliant 3-byte pointer before writing.
    # @param [String, Symbol] name the name of the table as specified
    #   in the ROM {Config} data.
    # @param [Integer] index in the case of a monster, the real index
    #   of the monster.
    # @return [String] a debug message.
    # @see offset_to_pointer
    def write_offset_to_table(name, index, offset)
      write(
        table(name) + index * 8,
        self.class.offset_to_pointer(offset)
      )
    end

    # Writes a stream of +length+ 0xFF bytes at the provided +offset+.
    # This ought to be recognized as free space available for writing.
    # Unless +force+ is set to true, the method will do nothing
    # if there may be multiple pointers referencing the given offset
    # within the ROM file.
    #
    # @param [Integer] offset
    # @param [Integer] length
    # @param [Boolean] force whether to force wiping even if the offset
    #   appears to be pointed at multiple times.
    # @return [String] a debug message.
    def wipe(offset, length, force = false)
      unless force
        pointer = self.class.offset_to_pointer(offset)

        @file.rewind
        hits = @file.read.scan(pointer).length
        if hits > 1
          return "Rom.wipe: Offset #{offset} (#{ format('%06X', offset) })" \
            " appears to be referenced by multiple pointers (#{hits})," \
            ' not wiping. Use wipe(offset, length, true) to override.'
        end
      end

      write(offset, "\xFF" * length)

      "Rom#wipe: Wiped #{length} bytes at #{offset}" \
        "(#{ format('%06X', offset) })."
    end

    # Closes the ROM file.
    #
    # @return [0]
    def close
      @file.close
      0
    end

    # Returns a blurb consisting of the ROM title and ID.
    #
    # @return [String]
    def to_s
      "#{ param(:title) } [#{@id}]"
    end

    private

    # Reads the type ID from the ROM file.
    #
    # @return [String]
    def load_id
      read(ID_OFFSET, 4)
    end
  end
end
