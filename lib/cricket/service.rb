#!/usr/bin/env ruby

module Service

  require 'csv'
  require 'mechanize'

  class Msan_Manual_Input

    FILENAME = File.expand_path 'config/msan_alternative_input.csv'

    def get
      result = []

      begin

        # The [1 .. -1] argument bypass the head row
        CSV.read(FILENAME, 'r', col_sep: ';')[1 .. -1].each do |row|
          result << Msan_Element.new do
            self.model = row[0]
            self.dms_id = row[1]
            self.rin = row[2]
            self.ip = row[3]
          end
        end
      rescue => err
        puts "Error loading external list file #{FILENAME.upcase} - #{err.class} #{err}"
      end

      result
    end

  end

  class Msan_Cricket_Scrapper

    # Function <tt>get_msan_list</tt> scraps MSAN information on Cricket page hosted at management network.
    # Sample page: http://10.200.1.220/cricket/grapher.cgi?target=%2Fdslams%2FCAS
    # Regex evaluated with http://regexpal.com/
    # Scrapper engine: http://mechanize.rubyforge.org/
    # Params:
    # +cnl+:: string of CLN to be searched.
    # @return [Array] data array.
    def get_msan_list(cnl)

      regex_rin = /\b[a-z]\d+[-]\w+[-]\d+\b/ # a01-rin-75
      regex_dms_id = /\b[A-Z]{3}-[-\w\d]+\W\B/ # CAS-I02 or CAS-A02-0
      regex_ip = /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/ # 10.211.161.69
      regex_model = /\b[M,Z][a-z]+\b/ # Milegate or Zhone

      # URL DSLAM page for the current CNL
      url = "http://10.200.1.220/cricket/grapher.cgi?target=%2Fdslams%2F#{cnl.to_s.upcase}"

      result = []

      # Loads GVT Cricket page
      begin
        page = Mechanize.new.get(url)

        # Iterates over each TR html tag in the page, scrapping RIN, DMS_ID, IP and DSLAM model to the bean
        page.search('tr').each do |tr|
          data = tr.inner_text
          if data.scan(regex_ip).length > 0

            result << Msan_Element.new do
              self.rin = data.scan(regex_rin).to_s.scan(/\b\d+/).join
              self.dms_id = data.scan(regex_dms_id).join
              self.ip = data.scan(regex_ip).join
              self.model = data.scan(regex_model).join
            end

          end
        end
      rescue => err
        puts "#{err.class} - #{err}"
      end

      result
    end
  end

  class Msan_Element
    attr_accessor(:model, :dms_id, :rin, :ip)

    def initialize(&block)
      instance_eval &block
    end
  end

end