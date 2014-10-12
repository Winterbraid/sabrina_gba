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
    a pure Ruby library. Compared to the many excellent GUI tools available,
    this library focuses on non-interactive manipulation of ROM data.
	EOT

	s.authors = ['Winterbraid']
	s.email = 'Winterbraid@users.noreply.github.com'
	s.homepage = 'https://github.com/Winterbraid/sabrina_gba'
	s.files = Dir['{lib}/**/*.rb', 'LICENSE']
	s.license = 'MIT'

	s.add_runtime_dependency('json')
	s.add_runtime_dependency('chunky_png')
end
