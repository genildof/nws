module Service

  require 'thread'
  require 'mechanize'

  class DMSW_Loader

    def get_csv_list
      [['D2SPO06I0202', '10.211.33.97', '106 B'], ['D2SPO01I0201', '10.211.119.160', '105']]
    end

  end

  class MSAN_Loader

    # Function <tt>get_msan_list</tt> scraps MSAN information from Cricket page hosted at management network.
    # Scrapped page: http://10.200.1.135/static/dslams/CAS/
    # Regex tests: https://regexr.com/
    # Scrapper engine: http://mechanize.rubyforge.org/
    # Params:
    # +cnl+:: string of CLN to be searched.
    # @return [Array] data array.
    def get_cricket_list(cnl)

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

    def get_csv_list

      filename = '../config/msan_alternative_input.csv'
      result = []

      begin

        # The [1 .. -1] argument bypass the head row
        CSV.read(filename, 'r', col_sep: ';')[1..-1].each do |row|
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

  class Msan_Element
    attr_accessor(:model, :dms_id, :rin, :ip)

    def initialize(&block)
      instance_eval &block
    end

    def to_s
      "#{model} #{dms_id} #{rin} #{ip}"
    end

    def to_array
      [model, dms_id, rin, ip]
    end
  end

  # http://www.proccli.com/2011/02/super-simple-thread-pooling-ruby
  #
  # Stupid simple "multi-threading" - it doesn't use mutex or queues but
  # it does have access to local variables, which is convenient. This will
  # break a data set into equal slices and process them, but it is not
  # perfect in that it will not start the next set until the first is
  # completely processed -- so, if you have 1 slow item it loses benefit
  # NOTE: this is not thread-safe!
  class ThreadPool
    def self.process!(data, size = 2, &block)
      Array(data).each_slice(size) do |slice|
        slice.map {|item| Thread.new {block.call(item)}}.map {|t| t.join}
      end
    end

    def initialize(size)
      @size = size
    end

    def process!(data, &block)
      self.class.process!(data, @size, &block)
    end
  end

end