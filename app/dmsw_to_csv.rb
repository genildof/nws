unless $0 != __FILE__
  require 'benchmark'
  require 'csv'
  require '../lib/service'
  require '../lib/datacom-api'

  HEADER = %w(HOST IP STATUS)
  WORKERS = 10

  LOGFILE = '../log/dmsw_logfile_%s.log' % Time.now.strftime('%d-%m-%Y_%H-%M')
  FILENAME = '../log/dmsw_report_%s.csv' % Time.now.strftime('%d-%m-%Y_%H-%M')
  CITY_LIST = %w"SPO BRE"
  result = []
  total_errors = 0
  errors = Array.new
  debugging = false

  jobs_list = Service::DMSW_Loader.new.get_csv_list

  print "\nStarting (Workers: %d Tasks: %d)...\n\n" % [WORKERS, jobs_list.size]
  pool = Service::ThreadPool.new(WORKERS)

  total_time = Benchmark.realtime {
    pool.process!(jobs_list) do |host|

      begin
        host_time = Benchmark.realtime {

          print "\tConnecting %s\n" % [host[1]]
          dmsw = Datacom::DMSW.new(host[1]) #1 is the index of IP address inside de host array

          if dmsw.connect
            puts "Connected."
          end

          result = dmsw.get_eaps_status

          # Prints eaps status
          if debugging
            puts HEADER
            print "\t%s -- %s\n" % [host.to_s, result.to_s]
          end

          dmsw.disconnect
        }

        # Prints partial statistics for current host
        print "\t%s -- %0.2f seconds\n" % [host.to_s, host_time]

        true

      rescue => err
        # Prints error log
        print "\t%s -- %s %s\n" % [host.to_s, err.class, err]

        # Increments error counter and appends log
        errors << " #{host.to_s} -- #{err.class} #{err}"
        total_errors += 1
      end
    end
  }

  # Prints total time
  print "\nJob done, total time: %0.2f seconds\n" % total_time

end