# unless $0 != __FILE__
require 'benchmark'
require 'net/ssh/telnet'
require '../lib/service'
require '../lib/datacom-api'

HEADER = %w(HOST IP STATUS)
WORKERS = 10

LOGFILE = '../log/dmsw_logfile_%s.log' % Time.now.strftime('%d-%m-%Y_%H-%M')
FILENAME = '../log/dmsw_report_%s.csv' % Time.now.strftime('%d-%m-%Y_%H-%M')

result = []
total_errors = 0
errors = Array.new

# job_list format ["106 B", "D2SPO06I0202", "HEADEND", "10.211.33.97", nil, "Anel Centro - Basilio da Gama", "SAO PAULO"]
jobs_list = Service::DMSW_Loader.new.get_excel_list

jobs_list.each {|value| puts value.to_s}

print "\nStarting (Workers: %d Tasks: %d)...\n\n" % [WORKERS, jobs_list.size]
pool = Service::ThreadPool.new(WORKERS)

total_time = Benchmark.realtime {


  pool.process!(jobs_list) do |host|

    eaps_status = []

    # ----------------------------------------------------------------- thread
    host_time = Benchmark.realtime {

      print "\tConnecting %s %s\n" % [host[1], host[4].to_s]

      dmsw = Datacom::DMSW.new
      dmsw.create_session

      if dmsw.connect(host[3]) #1 is the index of IP address inside de host array
        eaps_status = (dmsw.get_eaps_status)
        dmsw.disconnect()

        # Closes ssh main session
        dmsw.close_ssh_session
      end

    }
    # ----------------------------------------------------------------- thread

    result << host.concat(eaps_status)

    # Prints partial statistics for current host
    print "\t%s %s %s %s -- %s -- %0.2f seconds\n" % [host[1], host[3], host[5], host[0], eaps_status.to_s, host_time]
    begin
    rescue => err
      # Prints error log
      print "\t%s %s %s %s -- %s %s\n" % [host[1], host[3], host[5], host[0], err.class, err]

      # Increments error counter and appends log
      errors << "%s %s %s %s -- %s %s" % [host[1], host[3], host[5], host[0], err.class, err]
      total_errors += 1
    end

  end

}

result.each do |csv_row|
  puts csv_row.to_s
end

# Prints total time
print "\nJob done, total time: %0.2f seconds\n" % total_time

# end