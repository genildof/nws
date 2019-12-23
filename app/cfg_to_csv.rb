require 'rubygems'
require 'parseconfig'
my_config = ParseConfig.new('your_file.cfg')
puts my_config.get_value('key_val')