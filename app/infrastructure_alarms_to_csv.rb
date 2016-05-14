require 'thread'

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
    Array(data).each_slice(size) { |slice|
      slice.map { |item| Thread.new { block.call(item) } }.map { |t| t.join }
    }
  end

  def initialize(size)
    @size = size
  end

  def process!(data, &block)
    self.class.process!(data, @size, &block)
  end
end

# Playing around with it on the alphabet
# adjust the +WORKERS+ to adjust how many threads are
# being used at once
# noinspection RubyResolve
if $0 == __FILE__
  require 'benchmark'
  require 'csv'
  require_relative File.expand_path '../lib/cricket/service'
  require_relative File.expand_path '../lib/keymile/keymile-api'

  HEADER = %w(Shelf_ID RIN IP Alarm_Type Description)
  WORKERS = 50
  DSLAM_MODEL = [/Milegate/, /Zhone/]
  FILENAME = '../log/infrastructure_alarms_audit.csv' % Time.now.strftime('%d-%m-%Y_%H-%M')
  LOGFILE = '../log/infrastructure_robot_logfile.log'
  CITY_LIST = %w"SNE SBO MAU SVE SPO STS AUJ MCZ GRS OCO SOC VOM JAI VRP CAS IDU PAA RPO BRU ARQ"
  jobs_list = []
  memory_array = []
  total_system_alarms = 0
  total_card_alarms = 0
  total_cards_checked = 0
  total_redundancy_errors = 0
  total_remote_access_errors = 0
  remote_access_errors = Array.new

  CITY_LIST.each do |city|
    dslam_list = Service::Cricket_Dslam_Scrapper.new.get_dslam_list(city).select { |dslam|
      dslam.model.match(DSLAM_MODEL[0]) or dslam.model.match(DSLAM_MODEL[1]) }

    print "%s: %d element(s) found and enqueued.\n" % [city, dslam_list.size]
    dslam_list.each { |host| jobs_list << host }
  end

  jobs_list = jobs_list.concat(Service::Dslam_Manual_Input.new.get)

  print "Starting (Workers: %d Jobs: %d)\n" % [WORKERS, jobs_list.size]

  pool = ThreadPool.new(WORKERS)

  b = Benchmark.realtime {
    pool.process!(jobs_list) do |host|

      begin
        b = Benchmark.realtime {

          dslam = nil

          case host.model
            when /Milegate/
              dslam = Keymile::Milegate.new(host.ip)
            when /Zhone/
              dslam = Zhone::MXK.new(host.ip)
            else
              puts "Unknown DSLAM Model found: #{host.model} at #{host.ip}"
              remote_access_errors << "#{host.dms_id} #{host.rin} #{host.ip} Unknown DSLAM Model"
              total_remote_access_errors =+1
          end

          dslam.connect

          # Verifies system alarms on the shelf
          system_alarms = dslam.get_system_alarms
          card_alarms = dslam.get_card_alarms
          redundancy_alarms = dslam.get_redundancy_alarms

          total_cards_checked += dslam.get_all_cards.size
          total_system_alarms += system_alarms.size
          total_card_alarms += card_alarms.size
          total_redundancy_errors += redundancy_alarms.size

          system_alarms.each { |alarm| memory_array << [host.dms_id, host.rin, host.ip, 'System', alarm] }
          card_alarms.each { |alarm| memory_array << [host.dms_id, host.rin, host.ip, 'Card', alarm] }
          redundancy_alarms.each { |alarm| memory_array << [host.dms_id, host.rin, host.ip, 'Redundancy', alarm] }

          dslam.disconnect

          true
        }

        print "\t\tFinished: %s RIN %s - %s -- %0.2f seconds\n" % [host.dms_id, host.rin, host.ip, b]
      rescue => e
        print "\t\t>> Error: %s RIN %s - %s: %s\n" % [host.dms_id, host.rin, host.ip, e.inspect]
        remote_access_errors << "#{host.dms_id} #{host.rin} #{host.ip} #{e.inspect}"
        total_remote_access_errors =+1
      end
    end
  }

  print "\nWriting %s data rows to %s...\n" % [memory_array.size, FILENAME]

  # Saves data to csv file
  CSV.open(FILENAME, 'w', col_sep: ';') do |csv|
    csv << HEADER
    memory_array.each { |row| csv << row }
  end

  # Log file
  File.open(LOGFILE, 'a') { |f|

    f.puts "Statistics for #{FILENAME}"
    f.puts "+#{'-' * 100}+"
    f.puts "| Total checked NEs: #{jobs_list.size}"
    f.puts "| Total NE alarms: #{total_system_alarms.to_s}"
    f.puts "| Total cards checked: #{total_cards_checked.to_s}"
    f.puts "| Total card alarms: #{total_card_alarms.to_s}"
    f.puts "| Total redundancy alarms: #{total_redundancy_errors.to_s}"
    f.puts "| Total remote access errors: #{total_remote_access_errors.to_s}"
    f.puts '| Access errors'
    remote_access_errors.each { |error| f.puts "|\t#{error}" }
    f.puts "+#{'-' * 100}+\n\n"
  }

  # Output some times
  puts 'Finished all: %0.2f seconds' % b
end