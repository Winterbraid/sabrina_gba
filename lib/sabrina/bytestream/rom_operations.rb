module Sabrina
  class Bytestream
    # Methods related to writing and retrieving various ROM data.
    module RomOperations
      # @todo Return key +:original_length+ for {Lz77.uncompress} is currently
      #   unreliable. Wipe and overwrite in place for table data is disabled.
      #
      # Writes the byte data to the ROM, trying to use first the
      # table index and then the offset (and failing if neither is
      # known).
      #
      # If the table index is known, the data will be written to an
      # available free space on the ROM and the table will be updated.
      #
      # If the table data is unknown, the data will be written in place
      # at the offset.
      #
      # This method will call {#reload_from_rom} and update and return
      # the {#last_write} array.
      #
      # @return [Array] see {#last_write}.
      def write_to_rom
        old_length = calculate_length
        b = (@lz77 ? to_lz77 : to_bytes)
        new_length = b.length
        old_offset = offset

        unless @rom && old_offset
          fail 'Rom and offset or table/index must be set before writing.'
        end
        fail 'Byte string is empty. Aborting.' if b.empty?
        fail "Byte string too long #{new_length}. Aborting." if new_length > 10_000

        @last_write = []

        new_offset =
          if !@pointer_mode || !(@table && @index)
            @last_write << 'Bytestream#repoint: Overwriting in place.' \
            " (#{old_offset})"
            old_offset
            # Wipe and overwrite disabled due to
            # Lz77.uncompress[:original_length] inaccuracy.
            #
            # elsif new_length <= old_length
            # @last_write << 'Repoint: New length less than or equal to old' \
            #   'length, overwriting in place.'
            # @last_write << @rom.wipe(old_offset, old_length, true)
            # old_offset
          else
            o = repoint
            @last_write << 'Bytestream#repoint: Wiping disabled in this' \
              "version. Leaving #{old_length} bytes at #{old_offset}" \
              " (#{ format('%06X', old_offset) }) in #{@rom} intact."
            @last_write << "Bytestream#repoint: Repointed to #{o}" \
              " (#{ format('%06X', o) })."
            # @last_write << @rom.wipe(old_offset, old_length)
            o
          end

        @last_write << @rom.write(new_offset, b)
        clear_cache(lz77: false)

        @last_write
      end

      # Wipes the internal cache AND the representation so that the data
      # may be synced from ROM if present.
      #
      # @return [self]
      def reload_from_rom
        @representation = nil
        clear_cache
        present
        self
      end

      # Wipes the internal cache so that the data may be reloaded from ROM if
      # present.
      #
      # Subclasses should call this whenever the internal representation of
      # data is changed, and define {ByteOutput#generate_bytes} to
      # regenerate the byte data from the internal representation.
      #
      # @param [Hash] h
      #   @option h [Boolean] :lz77 whether to clear the internal representation
      #     as well (defaults to +true+).
      # @return [self]
      def clear_cache(h = { lz77: true })
        @lz77_cache = nil if h.fetch(:lz77, true)
        @length_cache = nil if h.fetch(:lz77, true) && !@lz77
        @bytes_cache = nil
        self
      end

      # @todo Return key +:original_length+ for {Lz77.uncompress} is currently
      #   unreliable. Wipe and overwrite in place for table data is disabled.
      #
      # Returns the length of the {Lz77} data stored on the ROM if +:lz77+
      # mode is on and a table of offset is provided. Otherwise, returns
      # the length of the byte data.
      #
      # @return [Integer]
      def calculate_length
        return @length_cache if @length_cache
        if @lz77 && offset
          return @length_cache = @rom.read_lz77(offset)[:original_length]
        end
        to_bytes.length
      end

      private

      # Assigns the data to a suitable free space on the ROM and updates
      # the table accordingly.
      #
      # This will clear the internal cache.
      #
      # @return [Integer] The offset found.
      def repoint
        unless @rom && @table && @index
          fail 'Rom, table and index must be set before repointing.'
        end

        l = (@lz77 ? to_lz77.length : to_bytes.length)
        f_offset = @rom.find_free(l)

        unless f_offset
          fail "Bytestream#repoint: Could not find #{l} bytes of free data in" \
            " #{@rom}. Consider using a clean rombase."
        end

        @rom.write_offset_to_table(@table, @index, f_offset)
        clear_cache
        f_offset
      end
    end
  end
end
