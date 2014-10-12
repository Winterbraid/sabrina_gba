module Sabrina
  module Plugins
    # This {Plugin} provides an abstraction for manipulating all
    # {Sprite Sprites} and {Palette Palettes} associated with a {Monster}.
    #
    # @see Plugin
    class Spritesheet < Plugin
      include ChildrenManager

      # @see Plugin::ENHANCES
      ENHANCES = Monster

      # @see Plugin::PLUGIN_NAME
      PLUGIN_NAME = 'Spritesheet'

      # @see Plugin::SHORT_NAME
      SHORT_NAME = 'spritesheet'

      # @see Plugin::FEATURES
      FEATURES = Set.new [:reread, :write, :save, :load]

      # @!attribute rom
      #   The current working ROM file.
      #   @return [Rom]
      # @!method rom=(r)
      #   The current working ROM file.
      #   @param [Rom] r
      #   @return [Rom]
      # @!attribute index
      #   The real index of the monster.
      #   @return [Integer]
      # @!method index=(i)
      #   The real index of the monster.
      #   @param [Integer] i
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

      # Generates a new Spritesheet object.
      #
      # @return [Spritesheet]
      def initialize(monster)
        @monster = monster
        @rom = monster.rom
        @index = monster.index

        @palettes = [
          Palette.from_table(@monster.rom, :palette_table, @monster.index),
          Palette.from_table(@monster.rom, :shinypal_table, @monster.index)
        ]

        @sprites = [
          Sprite.from_table(@monster.rom, :front_table, @monster.index),
          Sprite.from_table(@monster.rom, :back_table, @monster.index)
        ]
      end

      # @return [Array]
      # @see ChildrenManager
      def children
        @sprites + @palettes
      end

      # Justify sprites to the target ROM count as per ROM {Config}, assuming
      # 64x64 frame size.
      def justify
        @sprites.map(&:justify)
      end

      # Load data from a file.
      #
      # @return [Array] Any return data from child methods.
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
        children
      end

      # Save data to a file.
      #
      # @return [Array] Any return data from child methods.
      def save(file = @monster.filename, dir = @monster.work_dir, *_args)
        a = []
        @sprites.product(@palettes).each do |x|
          a << x.first.to_canvas(x.last)
        end

        path = get_path(file, dir, mkdir: true)

        combine_canvas(a).save(path)
      end

      private

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

      # Concatenate the file name and directory into a full path, optionally
      # creating the directory if it doesn't exist.
      #
      # @param [String] file
      # @param [String] dir
      # @param [Hash] h
      #   @option h [Boolean] :mkdir If +true+, create +dir+ if it doesn't
      #     exist.
      # @return [String]
      def get_path(file, dir, h = {})
        f, d = file.dup, dir.dup
        d << '/' unless d.empty? || d.end_with?('/')

        FileUtils.mkpath(d) if h.fetch(:mkdir, false) && !Dir.exist?(d)

        path = d << f
        path << '.png' unless path.downcase.end_with?('.png')
      end
    end
  end
end
