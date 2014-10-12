module Sabrina
  # A class dedicated to handling color palette data inside a ROM file.
  # This must be used alongside sprites to display the correct colors
  # in game or when exported to files.
  #
  # While a palette will function in this and some other programs even if
  # smaller than 16 colors, it must have exactly 16 colors to work in-game.
  # To ensure this, use the {#pad} method to fill the remaining slots with
  # a default color. This will, however, make it impossible to add further
  # colors.
  #
  # Parts adapted from
  # {https://github.com/thekaratekid552/Secret-Tool Gen III Hacking Suite}
  # by thekaratekid552.
  #
  # @see Sprite#set_palette
  class Palette < Bytestream
    class << self
      # Generates an array of two palettes from two +0xRRGGBB+-format streams:
      # One containing every color from +rgb1+, and another where each color is
      # replaced with its spatial equivalent from +rgb2+. This assumes
      # palette 1 does not contain duplicate entries, but palette 2 might.
      #
      # @param [String] rgb1 a string of +0xRRGGBB+ values.
      # @param [String] rgb2 a string of +0xRRGGBB+ values.
      # @param [Hash] h1 see {Bytestream#initialize}
      # @param [Hash] h2 see {Bytestream#initialize}
      # @return [Array] an array of the two resulting palettes.
      def create_synced_palettes(rgb1, rgb2, h1 = {}, h2 = {})
        unless rgb1.length % 3 == 0 && rgb2.length % 3 == 0
          fail 'RGB stream length must divide by 3.'
        end

        a1, a2 = rgb1.scan(/.../), rgb2.scan(/.../)
        pal1, pal2 = Palette.empty(h1), Palette.empty(h2)

        a1.each_index do |i|
          pix1 = a1[i].unpack('CCC')
          next if pal1.index_of(pix1)

          pix2 = a2[i].unpack('CCC')
          pal1.add_color(pix1)
          pal2.add_color(pix2, force: true)
        end

        [pal1.pad, pal2.pad]
      end

      # Same as {ByteInput#from_table_as_pointer}.
      #
      # @param [Hash] h see {Bytestream#initialize}
      # @return [Palette]
      # @see ByteInput#from_table_as_pointer
      def from_table(rom, table, index, h = {})
        from_table_as_pointer(rom, table, index, h)
      end

      # Generates a palette from a stream of bytes following the +0xRRGGBB+
      # format, failing if the total number of colors in the palette exceeds 16.
      #
      # @param [String] rgb
      # @param [Hash] h see {Bytestream#initialize}
      # @return [Sprite]
      def from_rgb(rgb, h = {})
        fail 'RGB stream length must divide by 3.' unless rgb.length % 3 == 0
        out_pal = empty(h)

        until rgb.empty?
          pixel = rgb.slice!(0, 3).unpack('CCC')
          out_pal.add(pixel) unless out_pal.index_of(pixel)
        end

        out_pal
      end

      # Returns an object representing an empty palette.
      #
      # @param [Hash] h see {Bytestream#initialize}
      # @return [Palette]
      def empty(h = {})
        h.merge!(representation: [])
        new(h)
      end

      # Returns a palette object represented by the given array
      # of [R,G,B] values. Caution is advised as there is no
      # validation.
      #
      # @param [Array] a
      # @return [Palette]
      def from_array(a = [], h = {})
        h.merge!(representation: a)
        new(h)
      end
    end

    # Same as {Bytestream#initialize}, but with +:lz77+
    # and +:pointer_mode+ set to true by default.
    #
    # @see Bytestream#initialize
    def initialize(h = {})
      @lz77 = true
      @pointer_mode = true

      super
    end

    # Pads the palette until it has the specified number of colors.
    # This is a mandatory step for the palette to actually work in-game.
    #
    # @param [Integer] l target size.
    # @param [Array] c the color to pad with, following the [R, G, B] format.
    # @return [self]
    def pad(l = 16, c = [16, 16, 16])
      add_color(c, force: true) until present.length >= l
      clear_cache
    end

    # Adds a color to the array. The color must be a [R, G, B] array.
    # Will fail on malformed color or 16 coors exceeded.
    #
    # This will clear the internal cache.
    #
    # @param [Array] color the color in [255, 255, 255] format.
    # @param [Hash] h
    #   @option h [Boolean] :force if +true+, add colors even if already
    #     present in the palette.
    # @return [self]
    def add_color(color, h = {})
      unless color.is_a?(Array) && color.length == 3
        fail "Color must be [R, G, B]. (#{color})"
      end

      color.each do |i|
        next if i.between?(0, 255)
        fail "Color component out of bounds. (#{color})"
      end

      @representation ||= []

      if @representation.index(color) && !h.fetch(:force, false)
        return clear_cache
      end
      @representation << color

      if present.length > 16
        fail "Palette must be smaller than 16. (#{present.length}, #{color})"
      end

      clear_cache
    end

    alias_method :add, :add_color

    # Returns the index of the [R, G, B] color in the palette,
    # or +nil+ if absent.
    #
    # @param [Array] color the color in [255, 255, 255] format.
    # @return [Integer]
    def index_of(color)
      present.index(color)
    end

    # Returns the palette as an array of [R, G, B] values.
    #
    # @return [Array]
    def present
      return @representation if @representation

      red_mask, green_mask, blue_mask = 0x1f, 0x3e0, 0x7c00

      in_bytes = to_bytes.dup
      out_array = []

      until in_bytes.empty?
        color = Bytestream.from_bytes(in_bytes.slice!(0, 2).reverse).to_i

        out_array << [
          (color & red_mask) << 3,
          (color & green_mask) >> 5 << 3,
          (color & blue_mask) >> 10 << 3
        ]
      end

      @representation = out_array
    end

    alias_method :to_a, :present

    # Converts the internal representation to a GBA-compatible
    # stream of bytes.
    #
    # @return [String]
    # @see ByteOutput#generate_bytes
    def generate_bytes
      pal = ''
      @representation.each do |c|
        red = c[0] >> 3
        green = c[1] >> 3 << 5
        blue = c[2] >> 3 << 10

        pal <<
          Bytestream.from_hex(format('%04X', (blue | green | red))).to_b.reverse
      end

      pal.rjust(2 * @representation.length, "\x00")
    end

    # A blurb showing the color count of the palette.
    #
    # @return [String]
    def to_s
      "Palette (#{present.length})"
    end
  end
end
