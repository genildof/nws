require 'csv'

class FileHandler
  TXT_SEP = ' '
  CSV_SEP = ?; # ?; for excel CSV and ?, for common CSV

  def get_csv_data(csv_file)
    list = Array.new
    CSV.open(csv_file, 'r', CSV_SEP) do |row|
      eqpto = row[4] || row[3]
      if eqpto != nil && eqpto.length == 10
        t = Tuple.new
        t.eqpto = eqpto
        t.instance = row[3]
        t.port = row[8]
        puts "Getting: #{t.instance} - #{t.eqpto}"
        list.push(t)
      end
    end
    list
  end

  def get_ibnlines_data(txt_file)
    list = Array.new
    File.open(txt_file, 'r') do |f1|
      while row == f1.gets
        eqpto = "#{row.split(TXT_SEP)[13]}#{row.split(TXT_SEP)[9]}"
        if eqpto != nil && eqpto.length == 10
          t = Tuple.new
          t.eqpto = eqpto
          t.instance = eqpto
          p_num = "#{row.split(TXT_SEP)[3]}#{row.split(TXT_SEP)[4]}".to_i(10)
          t.port = "#{row.split(TXT_SEP)[0]}-#{row.split(TXT_SEP)[1]}#{row.split(TXT_SEP)[2]}-#{p_num}"
          list.push(t)
        end
      end
    end
    list
  end

  class Tuple
    attr_accessor(:instance, :eqpto, :port, :obs)
    def initialize
      super()
    end
  end
end


