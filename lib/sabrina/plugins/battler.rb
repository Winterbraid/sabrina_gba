module Sabrina
  module Plugins
    # Handles information about sprite positioning on the battle screen.
    #
    # @see Plugin
    class Battler < Plugin
      # {include:Plugin::PLUGIN_NAME}
      PLUGIN_NAME = 'Battler'

      # {include:Plugin::SHORT_NAME}
      SHORT_NAME = 'battler'

      # {include:Plugin::SUFFIX}
      SUFFIX = '_battler.json'

      # The relevant data.
      STRUCTURE = [:enemy_y, :player_y, :enemy_alt]

      # @!attribute [rw] rom
      #   The current working ROM file.
      #   @return [Rom]
      # @!attribute [rw] index
      #   The real index of the monster.
      #   @return [Integer]
      # @!attribute [rw] enemy_y
      #   The vertical offset of the enemy sprite.
      #   @return [Integer]
      # @!attribute [rw] player_y
      #   The vertical offset of the player sprite.
      #   @return [Integer]
      # @!attribute [rw] enemy_alt
      #   The distance between the enemy sprite and its ground shadow. The enemy
      #   will not cast a shadow if this is set to zero.
      #   @return [Integer]

      # This breaks Yard.
      attr_accessor(:rom, :index, *STRUCTURE)

      # Reloads the data from a ROM, dropping any changes.
      #
      # @return [self]
      def reread
        STRUCTURE.each do |entry|
          bytes = @rom.read_table(entry.to_s << '_table', @index)
          value = bytes[1].unpack('C').first

          instance_variable_set('@' << entry.to_s, value)
        end

        self
      end

      # {include:Plugin#load_hash}
      def load_hash(hash)
        root_key = @index.to_s.to_sym

        return load_hash(hash[root_key]) if hash.key?(root_key)
        return load_hash(hash[:battler]) if hash.key?(:battler)

        STRUCTURE.each do |entry|
          value = hash.fetch(entry) { next }
          instance_variable_set('@' << entry.to_s, value.to_i)
        end

        self
      end

      # Returns a hash of battler data.
      #
      # @return [Hash]
      def to_hash
        hash = {}
        STRUCTURE.each do |entry|
          hash[entry] = instance_variable_get('@' << entry.to_s)
        end

        { @index => { battler: hash } }
      end

      alias_method :to_h, :to_hash
    end
  end
end
