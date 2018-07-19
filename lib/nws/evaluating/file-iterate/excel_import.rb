# To change this template, choose Tools | Templates
# and open the template in the editor.

require 'rubygems'
require 'poi'

workbook=POI::Workbook.open('./dados.xlsx')
rows=workbook.worksheets.first.rows
nomes=[]
rows.each do |row|
  nomes << row[0].valueunless
  row.index == 0
end

nomes.each{ |nome| puts nome}
