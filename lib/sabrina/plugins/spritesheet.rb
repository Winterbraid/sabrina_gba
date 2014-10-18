module Sabrina
  module Plugins
    # This {Plugin} provides an abstraction for manipulating all
    # {Sprite Sprites} and {Palette Palettes} associated with a {Monster}.
    #
    # @see Plugin
    class Spritesheet < Plugin
      include ChildrenManager

      # {include:Plugin::ENHANCES}
      ENHANCES = Monster

      # {include:Plugin::PLUGIN_NAME}
      PLUGIN_NAME = 'Spritesheet'

      # {include:Plugin::SHORT_NAME}
      SHORT_NAME = 'spritesheet'

      # {include:Plugin::SUFFIX}
      SUFFIX = '.png'

      # @!attribute [rw] rom
      #   The current working ROM file.
      #   @return [Rom]
      # @!attribute [rw] index
      #   The real index of the monster.
      #   @return [Integer]
      attr_children :rom, :index

      # The palettes used by the sprites.
      #
      # @return [Array]
      attr_reader :palettes

      # The sprites.
      #
      # @return [Array]
      attr_reader :sprites

      # {include:Plugin#reread}
      def reread
        @palettes = [
          Palette.from_table(@monster.rom, :palette_table, @monster.index),
          Palette.from_table(@monster.rom, :shinypal_table, @monster.index)
        ]

        @sprites = [
          Sprite.from_table(@monster.rom, :front_table, @monster.index),
          Sprite.from_table(@monster.rom, :back_table, @monster.index)
        ]

        self
      end

      # {include:Plugin#children}
      def children
        @sprites + @palettes
      end

      # Load data from a file.
      #
      # @return [self]
      def load(file = @monster.filename, dir = @monster.work_dir, *_args)
        path = get_path(file, dir)
        a = split_canvas(ChunkyPNG::Canvas.from_file(path))
        h = { rom: @rom, index: @index }

        normal_rgb = a[0].to_rgb_stream + a[2].to_rgb_stream
        shiny_rgb = a[1].to_rgb_stream + a[3].to_rgb_stream

        @palettes = Palette.create_synced_palettes(
          normal_rgb,
          shiny_rgb,
          h.merge(table: :palette_table),
          h.merge(table: :shinypal_table)
        )

        frames = @rom.special_frames.fetch(@index, @rom.frames)
        front = crop_canvas(a[0], frames.first * 64)
        back = crop_canvas(a[2], frames.last * 64)

        @sprites = [
          Sprite.from_canvas(
            front,
            @palettes.first,
            h.merge(table: :front_table)
          ),
          Sprite.from_canvas(
            back,
            @palettes.first,
            h.merge(table: :back_table)
          )
        ]

        justify
        self
      end

       # Converts the sprite data to a 256x PNG datastream.
      def to_file
        a = []

        @sprites.product(@palettes).each do |pair|
          a << pair.first.to_canvas(pair.last)
        end

        combine_canvas(a).to_datastream
      end

      private

      # Justify sprites to the target ROM count as per ROM {Config}, assuming
      # 64x64 frame size.
      def justify
        @sprites.map(&:justify)
      end

      # Crops the canvas to the specified height if taller.
      def crop_canvas(c, h)
        return c.crop(0, 0, c.width, h) if c.height > h
        c
      end

      # Horizontally combine a one-dimensional array of
      # {http://rdoc.info/gems/chunky_png/1.2.0/ChunkyPNG/Canvas Canvas}
      # objects into a single, wide canvas.
      #
      # @param [Array] a an array of Canvas objects.
      # @return [Canvas] the combined canvas.
      def combine_canvas(a)
        out_c = ChunkyPNG::Canvas.new(a.first.width * a.length, a.first.height)
        a.each_index { |i| out_c.replace!(a[i], a.first.width * i) }
        out_c
      end

      # Vertically combine a one-dimensional array of
      # {http://rdoc.info/gems/chunky_png/1.2.0/ChunkyPNG/Canvas Canvas}
      # objects into a single, tall canvas.
      #
      # @param [Array] a an array of Canvas objects.
      # @return [Canvas] the combined canvas.
      def combine_canvas_vert(a)
        out_c = ChunkyPNG::Canvas.new(a.first.width, a.first.height * a.length)
        a.each_index { |i| out_c.replace!(a[i], 0, a.first.height * i) }
        out_c
      end

      # Split a {http://rdoc.info/gems/chunky_png/1.2.0/ChunkyPNG/Canvas Canvas}
      # into an array of canvases horizontally.
      #
      # @param [Canvas] c
      # @param [Integer] w tile width.
      # @return [Array] an array of Canvas objects.
      def split_canvas(c, w = 64)
        out_a = []
        (c.width / w).times { |i| out_a << c.crop(i * w, 0, w, c.height) }
        out_a
      end
    end
  end
end
