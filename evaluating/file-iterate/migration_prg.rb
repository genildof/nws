require 'comp'
require 'find'

PATH = 'C:/Documents and Settings/g0001959/Meus documentos/migr_a45/'
CSV_FILE = PATH + 'tbs_23.csv'
TXT_FILE = PATH + 'ibnlines_23.txt'
BAR = ('%' * 150)

puts BAR
puts 'Listing path files...'

Find.find(PATH) do |f|
  type = case
  when File.file?(f) then 'F'
  when File.directory?(f) then 'D'
  else '?'
  end
  puts '#{type}: #{f}'
end

puts '\nLoading ibnlines #{TXT_FILE} file...'
file_handler = FileHandler.new
txt_list = file_handler.get_ibnlines_data(TXT_FILE)
puts 'Ibnlines file loaded, #{txt_list.size} objects found.'

puts '\nLoading #{CSV_FILE} TBS file...'
csv_list = file_handler.get_csv_data(CSV_FILE)
puts 'TBS file loaded, #{csv_list.size} objects found.'

puts '\nComparing TBS file with ibnlines file ...'
result = Array.new
csv_list.each do |t1|
  puts 'Listing: #{t1.eqpto}'
  t2 = txt_list.detect{|t| t.eqpto == t1.eqpto}
  if t2 == nil
    t1.obs = 'Não encontrado na lista da switch (T)'
    result.push(t1)
  elsif t2.port != t1.port
    t1.obs = 'TBS divergente da switch, TBS #{t1.port} e switch #{t2.port} (T)'
    result.push(t1)
  end
end

puts 'Reverse comparing...'
txt_list.each do |t1|
  t2 = csv_list.detect{|t| t.eqpto == t1.eqpto}
  if t2 == nil
    t1.obs = 'Não encontrado no planejamento (S)'
    result.push(t1)
  elsif t2.port != t1.port
    t3 = result.detect{|t| t.eqpto == t1.eqpto}
    if t3!= nil
      t2.obs = t2.obs + ' (S)'
    else
      t1.obs = 'TBS divergente da switch, TBS #{t2.port} e switch #{t1.port} (S)'
      result.push(t1)
    end
  end
end

puts '\nListing results...'
if result.size > 0
  puts 'Instância\tEquipamento\tPorta\t\tObservação'
end
result.each do |t|
  port = t.port + (' ' * 15)
  puts '#{t.instance}\t#{t.eqpto}\t#{port[0,13]}\t#{t.obs}'
end
puts 'Completed, there are #{result.size} problems to be verified.'
puts BAR
