module Sabrina
  module Plugins
    # This {Plugin} handles all attacks that a {Monster} learns through leveling
    # up, items, or tutoring.
    #
    # @see Plugin
    class Moveset < Plugin
      # {include:Plugin::PLUGIN_NAME}
      PLUGIN_NAME = 'Moveset'

      # {include:Plugin::SHORT_NAME}
      SHORT_NAME = 'moveset'

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
      #   All moves the monster can learn by level-up, as a set of two-element
      #   [level, index] arrays.
      #   @return [Set]
      # @!attribute [rw] tutor
      #   All moves the monster can learn via tutoring.
      #   @return [Set]

      # This breaks Yard.
      attr_accessor(:rom, :index, *STRUCTURE)

      alias_method :tm, :tech_machines

      alias_method :hm, :hidden_machines

      # Stores original level-up data between calls to read from ROM.
      #
      # @return [String]
      attr_reader :old_level

      # {include:Plugin#reread}
      def reread
        parse_machines
        parse_levelup
        parse_tutor if @rom.moveset_tutor_length > 0

        self
      end

      # {include:Plugin#children}
      def children
        opts = { rom: @rom, index: @index }

        streams_array = [
          Bytestream.from_bytes(
            unparse_machines, opts.merge(table: :moveset_machine_table)
          ),
          Bytestream.from_bytes(
            unparse_levelup,
            opts.merge(
              table: :moveset_level_table,
              old_length: @old_level.length,
              pointer_mode: true
            )
          )
        ]

        return streams_array unless @rom.moveset_tutor_length > 0

        streams_array << Bytestream.from_bytes(
          unparse_tutor, opts.merge(table: :moveset_tutor_table,)
        )
      end

      # Returns an annotated version of TM compatibility.
      #
      # @return [Set]
      def tm_pretty
        @tech_machines.map do |tech_machine|
          machine = tech_machine - 1
          move_i = @rom.read_table(:machine_table, machine, 2).unpack('S').first
          name = @rom.read_string_from_table(:move_name_table, move_i)

          "#{tech_machine} (#{name})"
        end
      end

      # Returns an annotated version of HM compatibility.
      #
      # @return [Set]
      def hm_pretty
        @hidden_machines.map do |hidden_machine|
          machine = hidden_machine + @rom.tm_count - 1
          move_i = @rom.read_table(:machine_table, machine, 2).unpack('S').first
          name = @rom.read_string_from_table(:move_name_table, move_i)

          "#{hidden_machine} (#{name})"
        end
      end

      # Returns an annotated version of the level-up learnset.
      #
      # @return [Set]
      def level_pretty
        @level.map do |learned_move|
          name = @rom.read_string_from_table(
            :move_name_table,
            learned_move.last
          )

          [learned_move.first, "#{learned_move.last} (#{name})"]
        end
      end

      # Returns an annotated version of tutor data.
      #
      # @return [Set]
      def tutor_pretty
        @tutor.map do |move|
          move_i = @rom.read_table(:tutor_table, move, 2).unpack('S').first
          name = @rom.read_string_from_table(:move_name_table, move_i)
          "#{move} (#{name})"
        end
      end

      # {include:Plugin#load_hash}
      def load_hash(hash)
        root_key = @index.to_s.to_sym

        return load_hash(hash[root_key]) if hash.key?(root_key)
        return load_hash(hash[:moveset]) if hash.key?(:moveset)

        STRUCTURE.each do |entry|
          next unless hash.key?(entry)
          value =
            if entry == :level
              hash[entry].map { |learned_move| learned_move.map(&:to_i) }
            else
              hash[entry].map(&:to_i)
            end

          instance_variable_set('@' << entry.to_s, value.to_set)
        end

        self
      end

      # Returns a hash of moveset data.
      #
      # @return [Hash]
      def to_hash
        hash = {
          tech_machines: tm_pretty,
          hidden_machines: hm_pretty,
          level: level_pretty,
          tutor: tutor_pretty
        }

        { @index => { moveset: hash } }
      end

      alias_method :to_h, :to_hash

      private

      # Get TM/HM data from the ROM.
      def parse_machines
        bytes = @rom.read_table(:moveset_machine_table, @index)
        bits = bytes.unpack('b*').first

        @tech_machines = Set.new
        @hidden_machines = Set.new

        bits.each_char.to_a.each_index do |index|
          next unless bits[index] == '1'
          next @tech_machines << index + 1 if index < @rom.tm_count
          @hidden_machines << (index - @rom.tm_count) + 1
        end

        self
      end

      # Pack TM/HM data into bytes.
      def unparse_machines
        machines =
          @tech_machines.map { |machine| machine - 1 } +
          @hidden_machines.map { |machine| machine + @rom.tm_count - 1 }

        bits = ''

        (@rom.tm_count + @rom.hm_count).times do |machine|
          machines.include?(machine) ? bits << '1' : bits << '0'
        end

        [bits.ljust(8 * @rom.moveset_machine_length, '0')].pack('b*')
      end

      # Get level up move data from the ROM.
      def parse_levelup
        bytes = @rom.read_table_until(
          :moveset_level_table, @index, 4, "\xFF\xFF"
        )

        @old_level = bytes.dup

        bits = bytes.scan(/../).map { |pair| pair.unpack('b*').first.reverse }
        bits.pop

        @level = Set.new

        bits.each do |learned_move|
          @level << [
            learned_move.slice(0, 7).to_i(2),
            learned_move.slice(7, 9).to_i(2)
          ]
        end

        self
      end

      # Pack level up move data into bytes.
      def unparse_levelup
        bytes_a = @level.map do |learned_move|
          level_bits = learned_move.first.to_s(2).rjust(7, '0')
          move_bits = learned_move.last.to_s(2).rjust(9, '0')
          [(level_bits + move_bits).reverse].pack('b*')
        end

        bytes_a.join('') << "\xFF\xFF"
      end

      # Get move tutor compatibility data from the ROM.
      def parse_tutor
        bytes = @rom.read_table(:moveset_tutor_table, @index)
        bits = bytes.unpack('b*').first

        @tutor = Set.new

        bits.each_char.to_a.each_index do |index|
          @tutor << index if bits[index] == '1'
        end

        self
      end

      # Pack move tutor data into bytes.
      def unparse_tutor
        bits = ''

        (@rom.moveset_tutor_length * 8).times do |move|
          @tutor.include?(move) ? bits << '1' : bits << '0'
        end

        [bits].pack('b*')
      end
    end
  end
end