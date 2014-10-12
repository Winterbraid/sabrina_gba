module Sabrina
  # A class for dealing with string data stored on a ROM.
  #
  # It is required that +:rom+ and either +:table+ and +:index+ (recommended)
  # or +:offset+ be set in order to enable writing back to a ROM file.
  class GBAString < Bytestream
    # The byte to recognize as a blank character (space) for
    # line breaking.
    BLANK = "\x00"

    # The byte used to right-pad short strings to the desired length.
    FILLER = "\x00"

    # The line break byte.
    NEWLINE = "\xFE"

    # The byte recognized as the end of GBA-encoded string data.
    TERMINATOR = "\xFF"

    # The fallback byte for GBA encoding.
    MISSING_HEX = "\x00"

    # The fallback character for GBA decoding.
    MISSING_CHR = '?'

    # An input string ending with this character will be treated as
    # already terminated.
    TERMINATOR_CHR = '$'

    class << self
      # Creates a new {GBAString} object from a ROM offset, attempting
      # to read it as a GBA-encoded, 0xFF-terminated string.
      #
      # @param [Rom] rom
      # @param [Integer, String] offset The offset to seek to in the ROM.
      #   See {Bytestream.parse_offset} for details.
      # @param [Hash] h see {Bytestream#initialize}
      # @return [GBAString]
      def from_rom(rom, offset, h = {})
        h.merge!(rom: rom, offset: offset)

        new(h)
      end

      # Same as {ByteInput#from_table}, but allows +index_length+
      # to default to 11 (the typical value for a monster name table)
      # and requires no +length+ due to implicit string mode.
      #
      # @return [GBAString]
      # @see ByteInput#from_table
      def from_table(rom, table, index, index_length = 11, h = {})
        super(rom, table, index, index_length, nil, h)
      end

      # Creates a new {GBAString} object from a string,
      # encoding it to GBA format and optionally normalizing to
      # +length+ and breaking within +break_range+.
      #
      # @param [String] s
      # @param [Integer] length
      # @param [Range] break_range
      # @param [Hash] h see {Bytestream#initialize}
      # @return [GBAString]
      def from_string(s, break_range = nil, length = nil, h = {})
        length ||= (s.end_with?('$') ? s.length : s.length + 1)

        h.merge!(
          representation: s,
          length: length,
          break_range: break_range
        )

        new(h)
      end
    end

    # Same as {Bytestream#initialize}, but with +:is_gba_string+
    # set to true by default and support for the following extra
    # options.
    #
    # @param [Hash] h
    # @option h [Range] :break_range where in the string to try and
    #   insert a newline.
    # @see Bytestream#initialize
    def initialize(h = {})
      @is_gba_string = true
      @break_range = nil

      super
    end

    # Attempts to decode the byte data as a GBA-encoded string.
    #
    # @return [String]
    def present
      return @representation if @representation

      charmap = Config.charmap_out
      # charmap.merge!(Config.charmap_out_special) if special

      a = []
      to_bytes.each_char do |x|
        hexcode = format('%02X', x.each_byte.to_a[0])
        a.push(charmap.fetch(hexcode, MISSING_CHR))
      end

      @representation = a.join('')
    end

    # Encodes the internal string data to a GBA-encoded byte stream.
    #
    # @return [String]
    def generate_bytes
      s = present.dup

      a = s.scan(/./).map do |x|
        hexcode = Config.charmap_in.fetch(x, MISSING_HEX)
        hexcode.hex.chr
      end

      if @length
        if a.length > @length
          a.slice!(@length..-1)
        else
          a << FILLER until a.length >= @length
        end
        a[-1] = TERMINATOR
      else
        a << TERMINATOR
      end

      if @break_range
        break_index = @break_range.first + (a[@break_range].rindex(BLANK) || 3)
        a[break_index] = NEWLINE
      end

      a.map { |x| x.force_encoding('ASCII-8BIT') }
        .join(''.force_encoding('ASCII-8BIT'))
    end

    # Returns the string representation with the end of string mark trimmed.
    #
    # @return [String]
    def to_s
      present.dup.chomp('$')
    end

    private

    # @see {Bytestream#load_settings}
    def load_settings(h)
      @break_range = h.fetch(:break_range, @break_range)
      super
    end
  end
end
