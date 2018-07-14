#!/usr/bin/env ruby

module Service

  require 'mechanize'

  class Msan_Manual_Input

    FILENAME = '../config/msan_alternative_input.csv'

    def get
      result = []

      begin

        # The [1 .. -1] argument bypass the head row
        CSV.read(FILENAME, 'r', col_sep: ';')[1..-1].each do |row|
          result << Msan_Element.new do
            self.model = row[0]
            self.dms_id = row[1]
            self.rin = row[2]
            self.ip = row[3]
          end
        end
      end

      result
    end

  end

  class Msan_Cricket_Scrapper

    # Function <tt>get_msan_list</tt> scraps MSAN information from Cricket page hosted at management network.
    # Scrapped page: http://10.200.1.135/static/dslams/CAS/
    # Regex tests: https://regexr.com/
    # Scrapper engine: http://mechanize.rubyforge.org/
    # Params:
    # +cnl+:: string of CLN to be searched.
    # @return [Array] data array.
    def get_msan_list(cnl)

      regex_rin = /\b[a-z]\d+[-]\w+[-]\d+\b/ # a01-rin-75
      regex_dms_id = /\b[A-Z]{3}-[-\w\d]+\W\B/ # CAS-I02 or CAS-A02-0
      regex_ip = /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/ # 10.211.161.69
      regex_model = /\b[M,Z][a-z]+\b/ # Milegate or Zhone

      # MSAN list page for the current CNL
      url = "http://10.200.1.135/static/dslams/#{cnl.to_s.upcase}/"

      result = []

      # Loads Cricket page
      begin
        page = Mechanize.new.get(url)

        # Iterates over each TR html tag in the page, scrapping RIN, DMS_ID, IP and DSLAM model to the bean
        page.search('tr').each do |tr|
          data = tr.inner_text
          if data.scan(regex_ip).length > 0

            result << Msan_Element.new do
              self.dms_id = data.scan(regex_dms_id)[0].to_s.strip!
              self.rin = data.scan(regex_rin)[0]
              #self.rin = data.scan(regex_rin).to_s.scan(/\b\d+/).join.strip!
              self.ip = data.scan(regex_ip)[0]
              self.model = data.scan(regex_model)[0].to_s
              #puts "#{self.rin} - #{self.dms_id} - #{self.ip} - #{self.model}"
            end
          end
        end
      end
      result
    end
  end

  class Msan_Element
    attr_accessor(:model, :dms_id, :rin, :ip)

    def initialize(&block)
      instance_eval &block
    end

    def to_s
      "#{@model} #{@dms_id} #{@rin} #{@ip}"
    end

    def to_array
      [@model, @dms_id, @rin, @ip]
    end
  end

end