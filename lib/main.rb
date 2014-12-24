# To change this template, choose Tools | Templates
# and open the template in the editor.

#require 'util'
require 'ocuppancy'

teste = OccupancyGenerator.new

puts "Listing the Occupancy directory content..."
list_dir('e:/dev/ocuppancy')
teste.do_iterate('e:/TBS_REL_OCUPACAO_DSLAM_OCO_20_06_11.xls')
puts "Done.\n"

puts "Starting..."
puts "End."

