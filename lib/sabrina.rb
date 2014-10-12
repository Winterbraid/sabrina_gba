# {include:file:README.rdoc}
module Sabrina; end

require 'set'
require 'fileutils'
require 'json'

begin
  require 'oily_png'
  Sabrina.const_set(:PNG, 'oily_png')
rescue
  require 'chunky_png'
  Sabrina.const_set(:PNG, 'chunky_png')
end

require 'sabrina/meta.rb'

require 'sabrina/config.rb'
require 'sabrina/config/main.rb'
require 'sabrina/config/charmap_in.rb'
require 'sabrina/config/charmap_out.rb'
require 'sabrina/config/charmap_out_special.rb'

require 'sabrina/lz77.rb'
require 'sabrina/children_manager.rb'

require 'sabrina/bytestream/byte_input.rb'
require 'sabrina/bytestream/byte_output.rb'
require 'sabrina/bytestream/rom_operations.rb'
require 'sabrina/bytestream.rb'

require 'sabrina/sprite.rb'
require 'sabrina/palette.rb'
require 'sabrina/gba_string.rb'

require 'sabrina/rom.rb'
require 'sabrina/monster.rb'

require 'sabrina/plugin/register.rb'
require 'sabrina/plugin/load.rb'
require 'sabrina/plugin.rb'

require 'sabrina/plugins/spritesheet.rb'
require 'sabrina/plugins/stats.rb'

Sabrina::Config.load_user_config
