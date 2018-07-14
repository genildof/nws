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

# Playing around with it on the alphabet
# adjust the +WORKERS+ to adjust how many threads are
# being used at once
# noinspection RubyResolve
if $0 == __FILE__
  require 'benchmark'
  require 'csv'
  require '../lib/cricket/service'
  require '../lib/keymile/keymile-api'
  require '../lib/zhone/zhone-api'

  HEADER = %w(MODEL MSAN RIN IP TYPE ITEM DESCRIPTION PRIORITY COMMENTS)
  WORKERS = 100
  FILENAME = '../log/infrastructure_alarms_report_%s.csv' % Time.now.strftime('%d-%m-%Y_%H-%M')
  LOGFILE = '../log/infrastructure_alarms_logfile_%s.log' % Time.now.strftime('%d-%m-%Y_%H-%M')
  CITY_LIST = %w"SNE SBO MAU SVE SPO STS AUJ MCZ GRS OCO SOC VOM JAI VRP CAS IDU PAA RPO BRU ARQ"
  jobs_list = []
  result = []
  total_system_alarms = 0
  total_card_alarms = 0
  total_cards_checked = 0
  total_interface_alarms = 0
  total_errors = 0
  errors = Array.new
  debugging = false

  print "Scrapping cricket host list...\n\n"
  CITY_LIST.each do |cnl|
    dslam_list = Service::Msan_Cricket_Scrapper.new.get_msan_list(cnl).select {
        |msan| msan.model.to_s =~ /Zhone/ or msan.model.to_s =~ /Milegate/}

    print "\t%s: %d element(s).\n" % [cnl, dslam_list.size]
    dslam_list.each {|host| jobs_list << host}
  end
  print "\nDone.\n"

  print "\nLoading alternative inputs...\n"
  jobs_list = jobs_list.concat(Service::Msan_Manual_Input.new.get)
  print "Done.\n"

  print "\nStarting (Workers: %d Tasks: %d)...\n\n" % [WORKERS, jobs_list.size]
  pool = ThreadPool.new(WORKERS)

  total_time = Benchmark.realtime {
    pool.process!(jobs_list) do |host|

      partial_alarms = 0

      begin
        host_time = Benchmark.realtime {

          msan = nil

          case host.model

          when /Milegate/
            msan = Keymile::Milegate.new(host.ip)

          when /Zhone/
            msan = Zhone::MXK.new(host.ip)

          else
            puts "Unknown Model found: #{host.model} at #{host.ip}"
            errors << "#{host.to_s} -- Unknown Model"
            total_errors = +1
          end

          msan.connect

          # Loads system, card and interface alarms
          system_alarms = msan.get_system_alarms
          card_alarms = msan.get_card_alarms
          interface_alarms = msan.get_interface_alarms

          # Generates statistics
          total_cards_checked += msan.get_all_cards.size
          total_system_alarms += system_alarms.size
          total_card_alarms += card_alarms.size
          total_interface_alarms += interface_alarms.size
          partial_alarms += (system_alarms.size + card_alarms.size + interface_alarms.size)

          # Concatenates host info to alarm info and appends to temporary array
          system_alarms.concat(card_alarms).concat(interface_alarms).each do |alarm|
            csv_row = host.to_array.concat(alarm)

            if debugging
              print "\t" + csv_row.to_s + "\n"
            end

            result << csv_row
          end

          msan.disconnect

          true
        }

        # Prints partial statistics for current host
        print "\t%s -- %0.2f seconds -- %s alarm(s)\n" % [host.to_s, host_time, partial_alarms]

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
          "| Total NE alarms: #{total_system_alarms.to_s}\n" +
          "| Total cards checked: #{total_cards_checked.to_s}\n" +
          "| Total card alarms: #{total_card_alarms.to_s}\n" +
          "| Total interface alarms: #{total_interface_alarms.to_s}\n" +
          "| Total errors: #{total_errors.to_s}\n" +
          "|\n| Errors:\n"
  errors.each {|error| statistics << "|#{error}\n"}
  statistics << "+#{'-' * 130}+\n"

  print "\n" + statistics

  print "\nWriting data rows to log file...\n"

  # Writes temporary arry to csv file
  CSV.open(FILENAME, 'w', col_sep: ';') do |csv|
    csv << HEADER
    result.map {|e| e ? e : ''} # replaces nil values
    result.each {|row| csv << row}
  end

  print "%s rows recorded in %s.\n" % [result.size, FILENAME]

  # Writes log file
  File.open(LOGFILE, 'a') {|f| f.puts statistics}
  print "\nLog file %s created.\n" % LOGFILE

  # Prints total time
  print "\nJob done, total time: %0.2f seconds\n" % total_time
end