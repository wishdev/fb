#!/bin/env ruby
require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = "fb"
  s.version = "0.5.9.1"
  s.date = "2009-05-03"
  s.summary = "Firebird and Interbase driver"
  s.requirements = "Firebird client library fbclient.dll"
  s.require_path = '.'
  s.email = "wishdev@gmail.com"
  s.homepage = "http://github.com/wishdev/fb/tree/master"
  s.rubyforge_project = "fblib"
  s.test_file = "test/FbTestSuite.rb"
  s.has_rdoc = true
  s.extra_rdoc_files = ['README']
  s.rdoc_options << '--title' << 'Fb -- Ruby Firebird Extension' << '--main' << 'README' << '-x' << 'test'
  s.files = ['extconf.rb', 'fb.c', 'README'] + Dir.glob("test/*")
  s.platform = case PLATFORM
    when /win32/ then Gem::Platform::WIN32
  else
    Gem::Platform::RUBY
  end
  s.extensions = ['extconf.rb'] if s.platform == Gem::Platform::RUBY
end

if __FILE__ == $0
  Gem.manage_gems
  Gem::Builder.new(spec).build
end
