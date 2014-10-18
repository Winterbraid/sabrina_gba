module Sabrina
  # @todo Rewrite this module.
  # An utility module for compressing and decompressing data in a
  # GBA-compliant {http://en.wikipedia.org/wiki/LZ77_and_LZ78 LZ77} format.
  #
  # This has mostly been ported directly from
  # {https://github.com/thekaratekid552/Secret-Tool/blob/master/lib/Tools/LZ77.py
  # Gen III Hacking Suite}'s corresponding tool by thekaratekid552 and
  # contributors.
  #
  # Credit goes to thekaratekid552, Jambo51, Shiny Quagsire,
  # DoesntKnowHowToPlay, Interdpth.
  #
  # == License
  #
  #   The MIT License (MIT)
  #
  #   Copyright (c) 2014 karatekid552
  #
  #   Permission is hereby granted, free of charge, to any person obtaining a copy
  #   of this software and associated documentation files (the "Software"), to deal
  #   in the Software without restriction, including without limitation the rights
  #   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  #   copies of the Software, and to permit persons to whom the Software is
  #   furnished to do so, subject to the following conditions:
  #
  #   The above copyright notice and this permission notice shall be included in
  #   all copies or substantial portions of the Software.
  #
  #   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  #   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  #   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  #   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  #   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  #   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  #   THE SOFTWARE.
  module Lz77
    class << self
      # Decompresses data from +offset+ in the ROM file as Lz77. This returns a
      # hash consisting of the uncompressed +:stream+ and the +:original_length+
      # of the compressed data, but the latter value is currently inaccurate and
      # should not be relied upon for wiping old data.
      #
      # @param [Rom] rom
      # @param [Integer] offset
      # @return [Hash] contains the uncompressed data as +:stream+, the
      #   estimated original compressed length as +:original_length+, and
      #   the original compressed data as +:original_stream+.
      def uncompress(rom, offset)
        f = rom.file
        f.seek(offset)

        test = f.read(1)
        unless test == "\x10"
          fail "Offset #{offset} in #{rom.filename} does not appear" \
            " to be lz77 data. (Found #{ format('%02X', test.unpack('C')) })"
        end

        target_length = Bytestream.from_bytes(f.read(3).reverse).to_i

        data = ''

        loop do
          bit_field = format('%08b', f.read(1).unpack('C').first)

          bit_field.each_char do |x|
            if data.length >= target_length
              compressed_length = f.pos - offset
              compressed_length += 1 until compressed_length % 4 == 0
              original = rom.read(offset, compressed_length)
              return {
                stream: data.slice(0, target_length),
                original_stream: original,
                original_length: compressed_length
              }
            end
            next data << f.read(1) if x == '0'

            r5 = f.read(1).unpack('C').first
            store = r5
            r6 = 3
            r3 = (r5 >> 4) + r6
            r6 = store
            r5 = r6 & 0xF
            r12 = r5 << 8
            r6 = f.read(1).unpack('C').first
            r5 = r6 | r12
            r12 = r5 + 1

            r3.times do
              unless (r5 = data[-r12])
                fail "Decompression failed at offset #{offset} in" \
                  " #{rom.filename}. Possible corrupted file or unknown" \
                  " compression method. #{[bit_field, r3, r5, r6, r12]}"
              end
              data << r5
            end
          end
        end
      end

      # Compresses the supplied stream of bytes as GBA-compliant Lz77 data.
      #
      # @param [String] data
      # @return [String] the compressed data.
      def compress(data)
        compressed = "\x10"
        compressed <<
          Bytestream.from_hex(format('%06X', data.length)).to_b.reverse

        index = 0
        w = 0xFFF
        window = ''
        lookahead = ''

        loop do
          bits = ''
          check = nil
          current_chunk = ''

          8.times do
            window = (index < w ? data[0, index] : data[(index % w)..index])
            lookahead = data[index..-1]

            if lookahead.nil? || lookahead.empty?
              unless bits.empty?
                while bits.length < 8
                  bits << '0'
                  current_chunk << "\x00"
                end
                compressed <<
                  Bytestream.from_hex(format('%02x', bits.to_i(2))).to_b <<
                  current_chunk
              end
              break
            end

            check = window.index(lookahead[0..2])
            if check
              bits << '1'
              length = 2
              store_length = 0
              store_check = 0
              while check && length < 18
                store_length = length
                length += 1
                store_check = check
                check = window.index(lookahead[0, length])
              end
              index += store_length
              store_length -= 3
              position = window.length - 1 - store_check
              store_length = store_length << 12
              current_chunk <<
                Bytestream.from_hex(format('%04X', (store_length | position))).to_b
            else
              index += 1
              bits << '0'
              current_chunk << lookahead[0]
            end
          end # 8.times

          if lookahead.nil? || lookahead.empty?
            unless bits.empty?
              while bits.length < 8
                bits << '0'
                current_chunk << "\x00"
              end
              compressed <<
                Bytestream.from_hex(format('%02x', bits.to_i(2))).to_b <<
                current_chunk
            end
            break
          end

          compressed <<
            Bytestream.from_hex(format('%02x', bits.to_i(2))).to_b <<
            current_chunk
        end # loop

        compressed << "\x00" until compressed.length % 4 == 0
        compressed
      end # compress
    end
  end
end
