lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'sabrina/meta.rb'

Gem::Specification.new do |s|
	s.name = 'sabrina'
	s.version = Sabrina::VERSION
	s.date = Sabrina::DATE
	s.summary = Sabrina::ABOUT

	s.description = <<-EOT
    A library for manipulating GBA ROMs of a popular monster collection RPG
    series. It is written entirely in Ruby and uses Chunky PNG, which is also
    a pure Ruby library.

    Compared to the many excellent GUI tools available, this library focuses on
    non-interactive manipulation of ROM data. Key features include:
    * Support for several automatically recognized base ROM types. Additional
      types can be supported by placing JSON files in the user's +.sabrina+
      directory.
    * Import and export sprite sheets to or from PNG files via Chunky PNG. The
      256x64 format (front, shiny front, back, shiny back) compatible with tools
      such as G3HS or A-Series is automatically recognized.
    * Direct transfer of data between two ROM files, bypassing the stage of
      opening several application windows or creating intermediary files on
      the HDD.
    * Access to low-level read-and-write operations on ROMs through Bytestream
      instances, with support for LZ77 compression and encoding/decoding text
      strings.
	EOT

	s.authors = ['Winterbraid']
	s.files = Dir['{lib}/**/*.rb', 'LICENSE']
	s.license = 'MIT'

	s.add_runtime_dependency('json')
	s.add_runtime_dependency('chunky_png')
end
