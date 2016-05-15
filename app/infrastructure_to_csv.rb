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
  require_relative File.expand_path 'lib/cricket/service'
  require_relative File.expand_path 'lib/keymile/keymile-api'
  require_relative File.expand_path 'lib/zhone/zhone-api'

  HEADER = %w(MSAN Shelf_ID RIN IP Alarm_Type Item Description Priority Comments)
  WORKERS = 100
  FILENAME = 'log/infrastructure_alarms_audit_%s.csv' % Time.now.strftime('%d-%m-%Y_%H-%M')
  LOGFILE = 'log/infrastructure_robot_logfile.log'
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
    dslam_list = Service::Msan_Cricket_Scrapper.new.get_msan_list(city).select { |msan|
      msan.model.match(/Milegate/) or msan.model.match(/Zhone/) }

    print "%s: %d element(s) found and enqueued.\n" % [city, dslam_list.size]
    dslam_list.each { |host| jobs_list << host }
  end

  print "\nLoading alternative inputs..."
  jobs_list = jobs_list.concat(Service::Msan_Manual_Input.new.get)
  print 'Done.'

  print "\n\nStarting (Workers: %d Jobs: %d)...\n\n" % [WORKERS, jobs_list.size]

  pool = ThreadPool.new(WORKERS)

  b = Benchmark.realtime {
    pool.process!(jobs_list) do |host|

      begin
        b = Benchmark.realtime {

          msan = nil

          case host.model
            when /Milegate/
              msan = Keymile::Milegate.new(host.ip)
            when /Zhone/
              msan = Zhone::MXK.new(host.ip)
            else
              puts "Unknown DSLAM Model found: #{host.model} at #{host.ip}"
              remote_access_errors << "#{host.dms_id} #{host.rin} #{host.ip} Unknown DSLAM Model"
              total_remote_access_errors =+1
          end

          msan.connect

          # Verifies system alarms on the shelf
          system_alarms = msan.get_system_alarms
          card_alarms = msan.get_card_alarms
          redundancy_alarms = msan.get_interface_alarms

          total_cards_checked += msan.get_all_cards.size
          total_system_alarms += system_alarms.size
          total_card_alarms += card_alarms.size
          total_redundancy_errors += redundancy_alarms.size

          system_alarms.each { |alarm| memory_array <<
              [host.model, host.dms_id, host.rin, host.ip, 'System', alarm[0], alarm[1], alarm[2], alarm[3]] }
          card_alarms.each { |alarm| memory_array <<
              [host.model, host.dms_id, host.rin, host.ip, 'Card', alarm[0], alarm[1], alarm[2], alarm[3]] }
          redundancy_alarms.each { |alarm| memory_array <<
              [host.model, host.dms_id, host.rin, host.ip, 'Interface', alarm[0], alarm[1], alarm[2], alarm[3]] }

          msan.disconnect

          true
        }
        print "%s %sRIN %s at %s -- %0.2fs done\n" % [host.model, host.dms_id, host.rin, host.ip, b]

      rescue => e
        print "\n+#{'-' * 79}"
        print ">> Error on %s RIN %s %s %s:\n>> %s" % [host.dms_id, host.rin, host.model, host.ip, e.inspect]
        print "\n+#{'-' * 79}\n"
        remote_access_errors << "#{host.dms_id} #{host.ip} #{host.model} #{e.inspect}"
        total_remote_access_errors =+1
      end
    end
  }

  print "\nWriting data rows to log file...\n"

  # Saves data to csv file
  CSV.open(FILENAME, 'w', col_sep: ';') do |csv|
    csv << HEADER
    memory_array.each { |row| csv << row }
  end

  print "%s rows recorded in %s.\n" % [memory_array.size, FILENAME]

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
    f.puts '| Access errors:'
    remote_access_errors.each { |error| f.puts "|\t#{error}" }
    f.puts "+#{'-' * 100}+\n\n"
  }

  print "\nLog file %s updated.\n" % LOGFILE

  # Output some times
  print "\nFinished all: %0.2f seconds\n" % b

end
