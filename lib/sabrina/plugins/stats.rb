module Sabrina
  module Plugins
    # @todo Finish this class.
    # This {Plugin} aids in manipulating the basic stats of any {Monster}.
    #
    # @see Plugin
    class Stats < Plugin
      # @see Plugin::ENHANCES
      ENHANCES = Monster

      # @see Plugin::PLUGIN_NAME
      PLUGIN_NAME = 'Stats'

      # @see Plugin::SHORT_NAME
      SHORT_NAME = 'stats'

      # @see Plugin::FEATURES
      FEATURES = Set.new [:reread, :write]

      # Describes the order in which various stats appear in the byte data.
      # All of these will also be converted into attributes on runtime and
      # can be modified directly.
      STRUCTURE = [
        :hp, :attack, :defense, :speed, :sp_atk, :sp_def, :type_1, :type_2,
        :catch_rate, :exp_yield, :ev_yield, :item_1, :item_2, :gender,
        :egg_cycles, :friendship, :level_curve, :egg_group_1, :egg_group_2,
        :ability_1, :ability_2, :safari_rate, :color_flip
      ]

      # Code names for level up types.
      LEVEL_CURVES = [
        'Medium-Fast', 'Erratic', 'Fluctuating', 'Medium-Slow', 'Fast', 'Slow'
      ]

      # Code names for egg groups.
      EGG_GROUPS = [
        'None', 'Monster', 'Water 1', 'Bug', 'Flying', 'Field', 'Fairy',
        'Grass', 'Human-Like', 'Water 3', 'Mineral', 'Amorphous', 'Water 2',
        'Ditto', 'Dragon', 'Undiscovered'
      ]

      # Where to pull descriptive names from if applicable, these can be arrays
      # or ROM tables.
      NAMES = {
        type_1: :type_table,
        type_2: :type_table,
        item_1: :item_table,
        item_2: :item_table,
        level_curve: LEVEL_CURVES,
        egg_group_1: EGG_GROUPS,
        egg_group_2: EGG_GROUPS,
        ability_1: :ability_table,
        ability_2: :ability_table
      }

      # @!attribute [rw] rom
      #   The current working ROM file.
      #   @return [Rom]
      # @!attribute [rw] index
      #   The real index of the monster.
      #   @return [Integer]
      attr_accessor(:rom, :index, *STRUCTURE)

      # Generates a new Stats object.
      #
      # @return [Stats]
      def initialize(monster)
        @monster = monster
        @rom = monster.rom
        @index = monster.index

        @stream = Bytestream.from_table(
          @rom,
          :stats_table,
          @monster.index,
          @rom.stats_length
        )

        parse_stats
      end

      # Returns the base stats total.
      #
      # @return [Integer]
      def total
        @hp + @attack + @defense + @speed + @sp_atk + @sp_def
      end

      # Reloads the data from a ROM, dropping any changes.
      #
      # @return [self]
      def reread
        parse_stats
        self
      end

      # Write data to the ROM.
      def write
        stream.write_to_rom
      end

      # Returns a {Bytestream} object representing the stats, ready to be
      # written to the ROM.
      #
      # @return [Bytestream]
      def stream
        Bytestream.from_bytes(
          unparse_stats,
          rom: @rom,
          table: :stats_table,
          index: @index
        )
      end

      # Returns a hash representation of the stats.
      #
      # @return [Hash]
      def to_h
        h = {}

        STRUCTURE.each do |entry|
          h[entry] = instance_variable_get('@' << entry.to_s)
        end

        { @index => { stats: h } }
      end

      # Returns a pretty hexadecimal representation of the stats byte data.
      #
      # @return [String]
      def to_hex
        stream.to_hex(true)
      end

      # Returns a pretty JSON representation of the stats.
      #
      # @return [String]
      def to_json
        JSON.pretty_generate(to_h)
      end

      # Returns a blurb containing the base stats total.
      #
      # @return [String]
      def to_s
        "<Stats (#{total})>"
      end

      private

      # Reads stats data from the ROM.
      def parse_stats
        b = @stream.to_bytes.dup

        STRUCTURE.each do |entry|
          value =
            case entry
            when :ev_yield
              parse_evs(b.slice!(0, 2))
            when :item_1, :item_2
              b.slice!(0, 2).unpack('S').first
            when :color_flip
              parse_color_flip(b.slice!(0))
            else
              b.slice!(0).unpack('C').first
            end

          pretty_value = prettify_stat(entry, value)
          instance_variable_set('@' << entry.to_s, pretty_value)
        end
      end

      # Converts stats data to a GBA-compatible byte string.
      def unparse_stats
        b = ''
        STRUCTURE.each do |entry|
          val = instance_variable_get('@' << entry.to_s)
          case entry
          when :ev_yield
            b << unparse_evs(val)
          when :item_1, :item_2
            b << [val.to_i].pack('S')
          when :color_flip
            b << unparse_color_flip(val)
          else
            b << [val.to_i].pack('C')
          end
        end

        b.ljust(28, "\x00")
      end

      # Attempts to annotate a numeric value with useful information.
      def prettify_stat(entry, value)
        return "#{value} (#{gender_info(value)})" if entry == :gender

        return value unless NAMES.key?(entry) && value.is_a?(Numeric)

        zero_is_valid = [:type_1, :type_2, :level_curve]
        return value if value == 0 && !zero_is_valid.include?(entry)

        return "#{value} (#{NAMES[entry][value]})" if NAMES[entry].is_a?(Array)

        "#{value} (#{ @rom.read_string_from_table(NAMES[entry], value) })"
      end

      # Displays readable info about the gender distribution defined by the
      # provided gender value.
      def gender_info(i)
        return 'Genderless' if i > 254
        return 'Always Female' if i == 254
        return 'Always Male' if i == 0
        "#{(100.0 * i / 255).round}% Female"
      end

      # Converts a word (two bytes) into a hash of EV yield data.
      def parse_evs(b)
        a = b.unpack('b*').first.scan(/../).map { |x| x.reverse.to_i(2) }
        h = {}

        a.take(6).each_index do |i|
          next if a[i] < 1
          h[STRUCTURE[i]] = a[i]
        end

        h
      end

      # Converts a hash of EV yield data into a word (two bytes).
      def unparse_evs(h)
        a = []

        STRUCTURE.take(6).each do |stat|
          ev = h.fetch(stat, 0)
          a << ev.to_s(2).rjust(2, '0').reverse
        end

        [a.join.ljust(16, '0')].pack 'b*'
      end

      # Converts a byte into an array of dex color and flip.
      def parse_color_flip(b)
        s = b.unpack('C').first.to_s(16).rjust(2, '0')

        [
          s[1].to_i,
          s[0] == '8' ? true : false
        ]
      end

      # Converts an array of dex color and flip into a byte.
      def unparse_color_flip(a)
        ((a.last ? '8' : '0') << a.first.to_s).hex.chr
      end
    end
  end
end
