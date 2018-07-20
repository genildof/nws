require 'benchmark'
require 'logger'
require '../lib/service'
require '../lib/datacom-api'

HEADER = %w(HOST IP STATUS)
WORKERS = 10 # according to the nmc ssh gateway limitation

LOGFILE = '../log/dmsw_logfile_%s.log' % Time.now.strftime('%d-%m-%Y_%H-%M')
FILENAME = '../log/dmsw_report_%s.csv' % Time.now.strftime('%d-%m-%Y_%H-%M')

result = []
total_errors = 0
errors = Array.new
logger = Logger.new(STDOUT)

jobs_list = Service::DMSW_Loader.new.get_excel_list

jobs_list.each {|value| puts value.to_s}
logger.info "Starting (Workers: %d Tasks: %d)..." % [WORKERS, jobs_list.size]

pool = Service::ThreadPool.new(WORKERS)

total_time = Benchmark.realtime {

  pool.process!(jobs_list) do |host|

    eaps_status = []

    begin

      # ----------------------------------------------------------------- thread
      host_time = Benchmark.realtime {

        dmsw = Datacom::DMSW.new

        if dmsw.connect(host[3]) #1 is the index of IP address inside de host array
          eaps_status = dmsw.get_eaps_status
          dmsw.disconnect
        end

      }
      # ----------------------------------------------------------------- thread

      result << host.concat(eaps_status)

      # Prints partial statistics for current host
      logger.info "%s %s %s %s -- %s -- %0.2f seconds" % [host[1], host[3], host[5], host[0], eaps_status.to_s, host_time]

    rescue => err
      error_msg = "%s %s %s %s -- %s %s" % [host[1], host[3], host[5], host[0], err.class, err]

      # Prints error log
      logger.info error_msg if $DEBUG

      # Appends log
      errors << error_msg

      total_errors += 1
    end

  end

}

result.each do |csv_row|
  logger.info csv_row.to_s
end

# Prints total time
print "\nJob done, total time: %0.2f seconds\n" % total_time