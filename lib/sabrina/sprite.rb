module Sabrina
  # A class tailored towards dealing with graphical (sprite) data.
  #
  # Note that a sprite generated from ROM data does not contain color data by
  # default. Pass a {Palette} as :palette in the option hash, or to
  # {#palette=}, to specify a default palette for the RGB output methods.
  class Sprite < Bytestream
    # Gets or sets the default palette for RGB output. Note that this will not
    # cause the palette to also be automatically written to ROM on sprite
    # {RomOperations#write_to_rom}.
    attr_accessor :palette

    class << self
      # Same as {ByteInput#from_table_as_pointer}, but also supports a
      # width parameter for the resulting picture.
      #
      # @param [Integer] width
      # @param [Hash] h see {Bytestream#initialize}
      # @return [Sprite]
      # @see ByteInput#from_table_as_pointer
      def from_table(rom, table, index, width = 64, h = {})
        h.merge!(width: width)
        from_table_as_pointer(rom, table, index, h)
      end

      # Same as {ByteInput#from_rom}, but supplies no +length+ (due to
      # implicit {Lz77} mode) and supports a width parameter for the resulting
      # picture.
      #
      # @param [Integer] width
      # @param [Hash] h see {Bytestream#initialize}
      # @return [Sprite]
      # @see ByteInput#from_rom
      def from_rom(rom, offset, width = 64, h = {})
        h.merge!(width: width)
        super(rom, offset, nil, h)
      end

      # Generates a sprite from a PNG file and optionally attempts to match the
      # colors to the provided {Palette}.
      #
      # Internally, this creates a
      # {http://rdoc.info/gems/chunky_png/1.2.0/ChunkyPNG/Canvas Canvas}
      # object from the provided file and then passes the extracted RGB stream
      # and width to {from_rgb} along with the palette.
      #
      # @param [String] file
      # @param [Palette] palette
      # @param [Hash] h see {Bytestream#initialize}
      # @return [Sprite]
      def from_png(file, palette = Palette.empty, h = {})
        c = ChunkyPNG::Canvas.from_file(file)

        from_canvas(c, palette, h)
      end

      # Generates a sprite from a
      # {http://rdoc.info/gems/chunky_png/1.2.0/ChunkyPNG/Canvas Canvas}
      # and optionally attempts to match the
      # colors to the provided {Palette}.
      #
      # @param [Canvas] c
      # @param [Palette] palette
      # @param [Hash] h see {Bytestream#initialize}
      # @return [Sprite]
      def from_canvas(c, palette = Palette.empty, h = {})
        from_rgb(c.to_rgb_stream, c.width, palette, h)
      end

      # Generates a sprite from a stream of bytes following the +0xRRGGBB+
      # format with the provided +width+, optionally matching the colors to the
      # supplied {Palette} (and failing if the sprite dimensions are not
      # multiples of 8 or the total number of colors in the image and the
      # palette exceeds 16).
      #
      # It is important to remember that while the resulting image will be ready
      # for saving to PNG, writing it to a ROM will not save the color data by
      # itself. The generated palette (accessible via {#palette}) should be
      # written separately. The {Plugins::Spritesheet Spritesheet} plugin should
      # take care of that for you.
      #
      # @param [String] rgb
      # @param [Integer] width
      # @param [Palette] palette
      # @param [Hash] h see {Bytestream#initialize}
      # @return [Sprite]
      def from_rgb(rgb, width = 64, palette = Palette.empty, h = {})
        fail 'RGB stream length must divide by 3.' unless rgb.length % 3 == 0

        unless width % 8 == 0 && (rgb.length / 3 / width) % 8 == 0
          fail 'Sprite dimensions must be divisible by 8.'
        end

        out_array = []

        until rgb.empty?
          pixel = rgb.slice!(0, 3).unpack('CCC')
          palette.add(pixel) unless palette.index_of(pixel)
          out_array << palette.index_of(pixel).to_s(16).upcase
        end

        h.merge!(
          representation: out_array,
          width: width,
          palette: palette
        )
        new(h)
      end
    end

    # Same as {Bytestream#initialize}, but with +:lz77+ and
    # +:pointer_mode+ set to true by default and support for the following extra
    # options.
    #
    # @param [Hash] h
    #   @option h [Integer] :width The width of the picture.
    #   @option h [Palette] :palette The default palette to use
    #     with the RGB and Canvas output methods.
    # @see Bytestream#initialize
    def initialize(h = {})
      @lz77 = true
      @pointer_mode = true

      @width = 64
      @palette = nil

      super
    end

    # Returns an array of characters that represent the palette index of each
    # pixel in hexadecimal format.
    #
    # @return [Array] an array of characters from 0 through F.
    def present
      return @representation if @representation
      # return nil if to_bytes.empty?

      in_array = []
      to_hex.scan(/(.)(.)/) { |x, y| in_array += [y, x] }

      column_num = @width / 8

      blocks = []
      blocks << in_array.slice!(0, 64) until in_array.empty?

      out_array = []
      i = 0
      loop do
        loop do
          break if blocks[i % column_num].empty?
          out_array += blocks[i % column_num].slice!(0, 8)
          i += 1
        end
        blocks.slice!(0, column_num)
        break if blocks.empty?
      end

      @representation = out_array
    end

    alias_method :to_a, :present

    # @todo Some breakage with number 360, is this the culprit?
    # Converts the internal representation to a GBA-compatible stream of bytes.
    #
    # @return [String]
    # @see ByteOutput#generate_bytes
    def generate_bytes
      in_array = []
      present.join('').scan(/(.)(.)/) { |x, y| in_array += [y, x] }

      column_num = @width / 8
      out_array = []

      loop do
        break if in_array.empty?
        columns = [[]] * column_num

        until columns[0].length == 8 * 8
          column_num.times { |i| columns[i] += in_array.slice!(0, 8) }
        end # Filled one block

        out_array += columns.slice!(0) until columns.empty?
      end

      Bytestream.from_hex(out_array.join('')).to_b
    end

    # Converts the internal representation to a stream of +0xRRGGBB+ bytes using
    # the default palette or the provided one (and failing if neither is
    # present.)
    #
    # @param [Palette] pal
    # @return [String]
    # @see #palette=
    def to_rgb(pal = @palette)
      fail 'A palette must be specified for conversion to RGB.' unless pal

      rgb = present.map do |x|
        color = pal.present[x.hex]
        fail "No such entry in the palette: #{x.hex}" unless color
        color.map(&:chr).join('')
      end

      rgb.join('')
    end

    # Crops or repeats the sprite vertically until it meets the current ROM's
    # frame count, assuming 64x64 pixels per frame.
    #
    # @return [self]
    def justify
      frame_count =
        if @table.to_sym == :front_table
          @rom.special_frames.fetch(@index, @rom.frames).first
        else
          @rom.special_frames.fetch(@index, @rom.frames).last
        end

      h = { lz77: false }
      target = frame_count * 64 * 64

      old_rep = @representation.dup
      if @representation.length < target
        @representation += old_rep until @representation.length >= target
        h = { lz77: true }
      elsif @representation.length > target
        @representation.slice!(0, target)
        h = { lz77: true }
      end

      clear_cache(h)
    end

    # @see Bytestream#rom=
    def rom=(p_rom)
      @rom = p_rom
      justify
      @rom
    end

    # Converts the internal representation to a
    # {http://rdoc.info/gems/chunky_png/1.2.0/ChunkyPNG/Canvas Canvas}
    # object using the default palette or the provided one (and failing if
    # neither is present.)
    #
    # @param [Palette] pal
    # @return [Canvas] a
    #   {http://rdoc.info/gems/chunky_png/1.2.0/ChunkyPNG/Canvas Canvas}
    #   object.
    # @see #palette=
    def to_canvas(pal = @palette)
      ChunkyPNG::Canvas.from_rgb_stream(
        @width,
        present.length / @width,
        to_rgb(pal)
      )
    end

    # Saves the internal representation to a PNG file (appending the file
    # extension if absent) using the default palette or the provided one (and
    # failing if neither is present.)
    #
    # @param [String] file the file to save to. A +.png+ extension is optional.
    # @param [Palette] pal
    # @see #palette=
    def to_png(file, dir = '', pal = @palette)
      dir << '/' unless dir.empty? || dir.end_with?('/')
      FileUtils.mkpath(dir) unless Dir.exist?(dir)

      path = dir << file
      path << '.png' unless path.downcase.end_with?('.png')

      to_canvas(pal).save(path)
    end

    alias_method :to_file, :to_png

    # Outputs the sprite as ASCII art with each pixel represented by the
    # hexadecimal value of its palette index.
    #
    # @param [Integer] width_multiplier each pixel will be repeated this
    #   many times horizontally. Defaults to 2 for better proportions
    #   with typical monospace fonts.
    # @return [String]
    # @see #palette=
    def to_ascii(width_multiplier = 2)
      output = ''
      present.each_index do |i|
        output << present[i] * width_multiplier
        output << "\n" if (i + 1) % @width == 0
      end
      output
    end

    # A blurb showing the sprite dimensions.
    #
    # @return [String]
    def to_s
      "Sprite (#{ @width }x#{ present.length / @width })"
    end

    private

    # @see {Bytestream#load_settings}
    def load_settings(h)
      @width = h.fetch(:width, @width)
      @palette = h.fetch(:palette, @palette)
      super
    end
  end
end
