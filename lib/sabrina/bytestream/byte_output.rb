module Sabrina
  class Bytestream
    # Methods that allow {Bytestream} to output the raw byte data
    # or export it to various formats. Subclasses should override {#to_bytes}
    # to allow generation from an internal representation if present,
    # and add to the list of output formats if necessary.
    module ByteOutput
      # Outputs a raw byte string. ROM and either table and index (recommended)
      # or offset should have been specified, otherwise the return string will
      # be empty. This method is relied on for write and save operations.
      #
      # This method uses an internal cache. The cache should be wiped
      # automatically on changes to ROM or internal data, otherwise it can
      # be wiped manually with {RomOperations#clear_cache}.
      #
      # Subclasses should define {#generate_bytes} to create the bytestream
      # from the internal representation instead and only read from the
      # ROM if the internal representation is absent.
      #
      # @return [String]
      def to_bytes
        return @bytes_cache if @bytes_cache
        return @bytes_cache = generate_bytes if @representation

        l_offset = offset
        if @rom && offset
          if @lz77
            data = @rom.read_lz77(l_offset)
            @length_cache = data[:original_length]
            @lz77_cache = data[:original_stream]
            return @bytes_cache = data[:stream]
          end
          return @bytes_cache = @rom.read_string(l_offset) if @is_gba_string
          return @bytes_cache = @rom.read(l_offset, @length) if @length
        end

        return ''
      end

      # Subclasses should override this to return a string of bytes generated
      # from the representation.
      def generate_bytes
        @bytes_cache = present
      end

      # Subclasses should override this to update the representation from
      # byte data.
      def present
        @representation ||= to_bytes
      end

      # Same as {#to_bytes}.
      def to_b
        to_bytes
      end

      # Returns a hexadecimal representation of the byte data, optionally
      # grouping it into quartets if passed +true+ as a parameter.
      #
      # @return [String]
      def to_hex(pretty = false)
        hex = to_bytes.each_byte.to_a.map { |byte| format('%02x', byte) }.join
        return hex unless pretty

        pretty_hex = []
        pretty_hex << hex.slice!(0, 8).scan(/../).join(':') until hex.empty?

        pretty_hex.join(' ')
      end

      # Same as {#to_hex}, but reverses the bytes before conversion.
      #
      # @return [String]
      def to_hex_reverse
        to_bytes.each_byte.to_a.map { |x| format('%02x', x) }.reverse.join('')
      end

      # Returns the byte data converted to a base-16 integer.
      # @return [Integer]
      def to_i
        to_hex.hex
      end

      # Outputs the byte data as a GBA-compatible {Lz77}-compressed
      # stream, raising an error when the data is empty.
      # {RomOperations#write_to_rom} relies on this
      # method when :lz77 is set to true.
      #
      # This method uses an internal cache. The cache should be wiped
      # automatically on changes to ROM or internal data, otherwise it can
      # be wiped manually with {RomOperations#clear_cache}.
      #
      # Subclasses should clear the internal cache by calling
      # {RomOperations#clear_cache} whenever the internal
      # representation has changed.
      # @return [String]
      def to_lz77
        return @lz77_cache if @lz77_cache
        b = to_bytes
        fail 'Cannot compress empty data.' if b.empty?
        @lz77_cache = Lz77.compress(b)
      end

      # Returns the output of {#to_hex}.
      #
      # Subclasses should override this to provide a concise textual
      # representation of the internal data.
      #
      # @return [String]
      def to_s
        "#{to_hex(true)}"
      end
    end
  end
end
