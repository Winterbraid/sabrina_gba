module Sabrina
  module Plugins
    # @todo Finish this class.
    # This {Plugin} handles all attacks that a {Monster} learns through leveling
    # up, items, or tutoring.
    #
    # @see Plugin
    class Moveset < Plugin
      include ChildrenManager

      # {include:Plugin::ENHANCES}
      ENHANCES = Monster

      # {include:Plugin::PLUGIN_NAME}
      PLUGIN_NAME = 'Moveset'

      # {include:Plugin::SHORT_NAME}
      SHORT_NAME = 'moveset'

      # {include:Plugin::FEATURES}
      FEATURES = Set.new [:reread]

      # {include:Plugin::SUFFIX}
      SUFFIX = '_moveset.json'

      # The relevant data.
      STRUCTURE = [:tech_machines, :hidden_machines, :level, :tutor]

      # @!attribute [rw] rom
      #   The current working ROM file.
      #   @return [Rom]
      # @!attribute [rw] index
      #   The real index of the monster.
      #   @return [Integer]
      # @!attribute [rw] tech_machines
      #   All TMs that the monster can learn.
      #   @return [Set]
      # @!attribute [rw] hidden_machines
      #   All HMs that the monster can learn.
      #   @return [Set]
      # @!attribute [rw] level
      #   All moves the monster can learn by level up, as a set of two-element
      #   [level, index] arrays.
      #   @return [Set]
      # @!attribute [rw] tutor
      #   All moves the monster can learn via tutoring.
      #   @return [Set]

      # This breaks Yard.
      attr_accessor(:rom, :index, *STRUCTURE)

      alias_method :tm, :tech_machines

      alias_method :hm, :hidden_machines

      # Generates a new Moveset object.
      #
      # @return [moveset]
      def initialize(monster)
        @monster = monster
        @rom = monster.rom
        @index = monster.index

        parse_machines
        parse_levelup
      end

      private

      # Get TM/HM data from the ROM.
      def parse_machines
        bytes = @rom.read_table(:moveset_machine_table, @index)
        bits = bytes.unpack('b*').first

        @tech_machines = Set.new []
        @hidden_machines = Set.new []

        bits.each_char.to_a.each_index do |index|
          next unless bits[index] == '1'
          next @tech_machines << index + 1 if index < @rom.tm_count
          @hidden_machines << (index - @rom.tm_count) + 1
        end

        self
      end

      # Get level up move data from the ROM.
      def parse_levelup
        bytes = @rom.read_table_until(
          :moveset_level_table, @index, 4, "\xFF\xFF"
        )

        bits = bytes.scan(/../).map { |pair| pair.unpack('b*').first.reverse }
        bits.pop

        @level = Set.new []

        bits.each do |learned_move|
          @level << [
            learned_move.slice(0, 7).to_i(2),
            learned_move.slice(7, 9).to_i(2)
          ]
        end

        self
      end
    end
  end
end