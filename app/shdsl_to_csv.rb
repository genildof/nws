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


  HEADER = %w(Shelf_ID RIN IP Slot_ID Slot_Name Slot_Main_Mode Slot_State Slot_Alarm Slot_Prop_Alarm Port_ID Port_Main_Mode Port_State
          Port_Alarm Port_User_Label Port_Service_Label OperationalStatus NearEnd_CurrentAttenuation NearEnd_CurrentMargin
          NearEnd_CurrentPowerBackOff FarEnd_CurrentAttenuation FarEnd_CurrentMargin FarEnd_CurrentPowerBackOff) #Port_Description
  WORKERS = 100
  DSLAM_MODEL = 'Milegate'
  CARD_TYPE = /STIM/
  LOGFILE = 'log/shdsl_robot_logfile.log'
  FILENAME = 'reports/shdsl_ports_audit_%s.csv' % Time.now.strftime('%d-%m-%Y_%H-%M')
  CITY_LIST = %w"SNE SBO MAU SVE SPO STS AUJ MCZ GRS OCO SOC VOM JAI VRP CAS IDU PAA RPO BRU ARQ"
  jobs_list = []
  memory_array = []
  total_errors = 0
  errors = Array.new

  CITY_LIST.each do |city|
    dslam_list = Service::Msan_Cricket_Scrapper.new.get_msan_list(city).select { |dslam| dslam.model.match(DSLAM_MODEL) }

    print "%s: %d %s(s) found and enqueued.\n" % [city, dslam_list.size, DSLAM_MODEL]
    dslam_list.each { |host| jobs_list << host }
  end

  print "\nLoading alternative inputs..."
  jobs_list = jobs_list.concat(Service::Msan_Manual_Input.new.get)
  print 'Done.'

  print "\n\nStarting (Workers: %d Tasks: %d)...\n\n" % [WORKERS, jobs_list.size]

  pool = ThreadPool.new(WORKERS)

  b = Benchmark.realtime {
    pool.process!(jobs_list) do |host|

      begin
        b = Benchmark.realtime {

          msan = Keymile::Milegate.new(host.ip)
          msan.connect

          msan.get_cards_by_name(CARD_TYPE).each do |slot|
            msan.get_shdsl_ports_all(slot).each do |port|
              row = [host.dms_id, host.rin, host.ip, slot.id, slot.name, slot.main_mode, slot.state, slot.alarm,
                     slot.prop_alarm, port.id, port.main_mode, port.state, port.alarm, port.user_label,
                     port.service_label] #port.description
              msan.get_shdsl_params(slot, port).each { |values| row << values }
              memory_array << row
            end
          end

          msan.disconnect
        }
        print "\tFinished: %s RIN %s - %s -- %0.2f seconds\n" % [host.dms_id, host.rin, host.ip, b]

      rescue => err
        puts "\n#{host.dms_id} #{host.ip} #{host.model} #{err.class} #{err}"
        errors << "#{host.dms_id} #{host.ip} #{host.model} #{err.class} #{err}"
        total_errors += 1
      end
    end
  }

  print "\nWriting %s data rows to log file...\n"
  CSV.open(FILENAME, 'w', col_sep: ';') do |csv|
    csv << HEADER
    memory_array.each { |service_data| csv << service_data }
  end
  print "%s rows recorded in %s.\n" % [memory_array.size, FILENAME]

  # Log file
  File.open(LOGFILE, 'a') { |f|

    f.puts "Statistics for #{FILENAME}"
    f.puts "+#{'-' * 100}+"
    f.puts "| Total errors: #{total_errors.to_s}"
    f.puts "|\n| Errors:"
    errors.each { |error| f.puts "|#{error}" }
    f.puts "+#{'-' * 100}+\n\n"
  }

  print "\nLog file %s updated.\n" % LOGFILE

  # Output some times
  print "\nFinished all: %0.2f seconds\n" % b
end