module Sabrina
  class Bytestream
    # Constructors that allow {Bytestream} to create byte data
    # from ROMs or other sources. All methods should accept an optional
    # final hash of options.
    #
    # Subclasses should override or add to these methods as necessary,
    # using the final hash to pass the internal representation and
    # any other necessary parameters and defaults.
    module ByteInput
      # Creates a new {Bytestream} object from bytes.
      #
      # @param [String] b
      # @param [Hash] h see {Bytestream#initialize}
      # @return [Bytestream]
      def from_bytes(b, h = {})
        h.merge!(bytes_cache: b)

        new(h)
      end

      # Creates a new {Bytestream} object that will read +length+
      # bytes of data from a ROM +table+ and +index+, expecting each entry
      # before the index to be +index_length+ bytes.
      #
      # @param [Rom] rom
      # @param [String, Symbol] table a key specified in rom_data config.
      # @param [Integer] index the index to read from the table.
      #   For monsters, it should be the real (not dex) number
      #   of the monster you wish to act on.
      # @param [Integer] index_length the expected length of a single entry.
      # @param [Integer] length how many bytes to read from the calculated
      #   offset.
      # @param [Hash] h see {Bytestream#initialize}
      # @return [Bytestream]
      def from_table(rom, table, index, index_length, length = index_length, h = {})
        h.merge!(
          rom: rom,
          table: table,
          index: index,
          index_length: index_length,
          length: length
        )

        new(h)
      end

      # Creates a new {Bytestream} object that will read a pointer
      # from a ROM table and index. This is the recommended method to
      # read monster data from a ROM.
      #
      # @param [Rom] rom
      # @param [String, Symbol] table a key specified in rom_data config.
      # @param [Integer] index the index to read from the table.
      #   For monsters, it should be the real (not dex) number
      #   of the monster you wish to act on.
      # @param [Hash] h see {Bytestream#initialize}
      # @return [Bytestream]
      def from_table_as_pointer(rom, table, index, h = {})
        h.merge!(
          rom: rom,
          table: table,
          index: index,
          pointer_mode: true
        )

        new(h)
      end

      # Creates a new {Bytestream} object by reading +length+
      # bytes from a ROM offset.
      #
      # @param [Rom] rom
      # @param [Integer, String] offset The offset to seek to in the ROM.
      #   See {Bytestream.parse_offset} for details.
      # @param [Integer] length
      # @param [Hash] h see {Bytestream#initialize}
      # @return [Bytestream]
      def from_rom(rom, offset, length = nil, h = {})
        h.merge!(
          rom: rom,
          offset: offset,
          length: length
        )

        new(h)
      end

      # Creates a new {Bytestream} object from a ROM offset, attempting
      # to read it as {Lz77}-compressed data.
      #
      # @param [Rom] rom
      # @param [Integer, String] offset The offset to seek to in the ROM.
      #   See {Bytestream.parse_offset} for details.
      # @param [Hash] h see {Bytestream#initialize}
      # @return [Bytestream]
      def from_rom_as_lz77(rom, offset, h = {})
        h.merge!(
          rom: rom,
          offset: offset,
          lz77: true
        )

        new(h)
      end

      # Same as {#from_bytes}, but takes a hexadecimal string that will be
      # converted to bytes.
      #
      # @param [String] s
      # @param [Hash] h see {Bytestream#initialize}
      # @return [Bytestream]
      def from_hex(s, h = {})
        if /[^0-9a-fx]/ =~ s.downcase
          fail "\'#{s}\' does not look like a hex string."
        end

        b = s.rpartition('x').last.scan(/../).map { |x| x.hex.chr }.join('')

        h.merge!(bytes_cache: b)

        new(h)
      end
    end
  end
end
