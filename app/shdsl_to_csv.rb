#!/usr/bin/env ruby
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
    Array(data).each_slice(size) {|slice|
      slice.map {|item| Thread.new {block.call(item)}}.map {|t| t.join}
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
  require_relative '../lib/cricket/service'
  require_relative '../lib/keymile/keymile-api'


  HEADER = %w(Shelf_ID RIN IP Slot_ID Slot_Name Slot_Main_Mode Slot_State Slot_Alarm Slot_Prop_Alarm Port_ID Port_Main_Mode Port_State
          Port_Alarm Port_User_Label Port_Service_Label OperationalStatus NearEnd_CurrentAttenuation NearEnd_CurrentMargin
          NearEnd_CurrentPowerBackOff FarEnd_CurrentAttenuation FarEnd_CurrentMargin FarEnd_CurrentPowerBackOff) #Port_Description
  WORKERS = 100
  DSLAM_MODEL = 'Milegate'
  SHDSL_CARD_NAME = /STIM/
  LOGFILE = '../log/shdsl_ports_logfile_%s.log' % Time.now.strftime('%d-%m-%Y_%H-%M')
  FILENAME = '../log/shdsl_ports_report_%s.csv' % Time.now.strftime('%d-%m-%Y_%H-%M')
  CITY_LIST = %w"SNE SBO MAU SVE SPO STS AUJ MCZ GRS OCO SOC VOM JAI VRP CAS IDU PAA RPO BRU ARQ"
  jobs_list = []
  result = []
  total_errors = 0
  errors = Array.new

  CITY_LIST.each do |cnl|
    dslam_list = Service::Msan_Cricket_Scrapper.new.get_msan_list(cnl).select {|dslam| dslam.model.match(DSLAM_MODEL)}

    print "%s: %d %s(s) found and enqueued.\n" % [cnl, dslam_list.size, DSLAM_MODEL]
    dslam_list.each {|host| jobs_list << host}
  end

  print "\nLoading alternative inputs..."
  jobs_list = jobs_list.concat(Service::Msan_Manual_Input.new.get)
  print 'Done.'

  print "\n\nStarting (Workers: %d Tasks: %d)...\n\n" % [WORKERS, jobs_list.size]

  pool = ThreadPool.new(WORKERS)

  total_time = Benchmark.realtime {
    pool.process!(jobs_list) do |host|

      active_ports = 0

      begin
        host_time = Benchmark.realtime {

          msan = Keymile::Milegate.new(host.ip)
          msan.connect

          # Iterates over each shdsl card found
          msan.get_cards_by_name(SHDSL_CARD_NAME).each do |slot|

            # Iterates over each active shdsl port in the shelf
            msan.get_shdsl_ports_all(slot).each do |port|
              row = [host.dms_id, host.rin, host.ip, slot.id, slot.name, slot.main_mode, slot.state, slot.alarm,
                     slot.prop_alarm, port.id, port.main_mode, port.state, port.alarm, port.user_label,
                     port.service_label] #port.description

              # Picks up snr and attenuation values of each port
              msan.get_shdsl_params(slot, port).each {|values| row << values}

              # Appends to temporary array
              result << row

              # Increments port counter
              active_ports += 1
            end
          end

          msan.disconnect
        }

        # Prints partial statistics for current host
        print "\t%s -- %0.2f seconds -- %s active port(s)\n" % [host.to_s, host_time.to_s, active_ports]

      rescue => err
        # Prints error log
        print "\t%s -- %s %s\n" % [host.to_s, err.class, err]

        # Increments error counter and appends log
        errors << " #{host.to_s} -- #{err.class} #{err}"
        total_errors += 1
      end
    end
  }

  statistics =
      "Statistics for #{FILENAME}\n" +
          "+#{'-' * 130}+\n" +
          "| Total checked NEs: #{jobs_list.size}\n" +
          "| Total errors: #{total_errors.to_s}\n" +
          "|\n| Errors:\n"
  errors.each {|error| statistics << "|#{error}\n"}
  statistics << "+#{'-' * 130}+\n"

  print "\n" + statistics

  print "\nWriting data rows to log file...\n"

  # Writes temporary arry to csv file
  CSV.open(FILENAME, 'w', col_sep: ';') do |csv|
    csv << HEADER
    result.each {|row| csv << row}
  end

  print "%s rows recorded in %s.\n" % [result.size, FILENAME]

  # Writes log file
  File.open(LOGFILE, 'a') {|f| f.puts statistics}
  print "\nLog file %s created.\n" % LOGFILE

  # Prints total time
  print "\nJob done, total time: %0.2f seconds\n" % total_time

end