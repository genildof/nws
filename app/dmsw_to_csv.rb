# unless $0 != __FILE__
require 'benchmark'
require '../lib/service'
require '../lib/datacom-api'

HEADER = %w(HOST IP STATUS)
WORKERS = 1

LOGFILE = '../log/dmsw_logfile_%s.log' % Time.now.strftime('%d-%m-%Y_%H-%M')
FILENAME = '../log/dmsw_report_%s.csv' % Time.now.strftime('%d-%m-%Y_%H-%M')
CITY_LIST = %w"SPO BRE"
result = []
total_errors = 0
errors = Array.new

jobs_list = Service::DMSW_Loader.new.get_excel_list

dmsw = Datacom::DMSW.new
dmsw.create_session

print "\nStarting (Workers: %d Tasks: %d)...\n\n" % [WORKERS, jobs_list.size]
pool = Service::ThreadPool.new(WORKERS)

total_time = Benchmark.realtime {
  pool.process!(jobs_list) do |host|

    begin

      host_time = Benchmark.realtime {
        print "\tConnecting %s\n" % [host[1]]

        telnet = dmsw.connect(host[1]) #1 is the index of IP address inside de host array
        if telnet != nil
          result = dmsw.get_eaps_status
          dmsw.disconnect(telnet)
          # Prints partial statistics for current host
        end
      }
      print "\t%s %s %s %s -- %s -- %0.2f seconds\n" % [host[0], host[1], host[2], host[3], result.to_s, host_time]

    rescue => err
      # Prints error log
      print "\t%s -- %s %s\n" % [host.to_s, err.class, err]

      # Increments error counter and appends log
      errors << "#{host.to_s} -- #{err.class} #{err}"
      total_errors += 1

    end
  end
}

# Closes ssh main session
dmsw.close_ssh_session

# Prints total time
print "\nJob done, total time: %0.2f seconds\n" % total_time

# end