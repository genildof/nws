require 'benchmark'
#require 'logger'
require 'csv'
require '../lib/datacom-api'
require '../lib/service'

#["106 B", "D2SPO06I0202", "HEADEND", "10.211.33.97", nil, "Anel Centro - Basilio da Gama", "SAO PAULO"]
HEADER = %w(SUB HOST TYPE IP CUSTOMER RING CITY Domain State Mode Port Port VLAN Groups_VLANs)
WORKERS = 10 # according to the nmc ssh gateway limitation

LOGFILE = '../log/dmsw_logfile_%s.log' % Time.now.strftime('%d-%m-%Y_%H-%M')
FILENAME = '../log/dmsw_report_%s.csv' % Time.now.strftime('%d-%m-%Y_%H-%M')

result = []
total_errors = 0
errors = Array.new

logger = Logger.new(STDOUT)

spinner = self.get_spinner_enumerator

job_list = Service::DMSW_Loader.new.get_excel_list

puts "passed."
printf "\n%s  Starting (Workers: %d Tasks: %d)..." % [spinner.next, WORKERS, job_list.size]

pool = Service::ThreadPool.new(WORKERS)

total_time = Benchmark.realtime {

  pool.process!(job_list) do |host|

    eaps_status = []

    begin

      # ----------------------------------------------------------------- thread
      host_time = Benchmark.realtime {

        dmsw = Datacom::DMSW.new

        if dmsw.connect(host[3]) #1 is the index of IP address inside de host array
          eaps_status = dmsw.get_eaps_status
          eaps_status = "no eaps configured" if eaps_status.nil?
          dmsw.disconnect
        end

      }
      # ----------------------------------------------------------------- thread

      result << host.concat(eaps_status)

      # Prints partial statistics for current host
      printf "%s  %s %s %s %s -- %s -- %0.2f seconds" % [spinner.next, host[1], host[3], host[5], host[0], eaps_status.to_s, host_time]

    rescue => err
      error_msg = "%s %s %s %s -- %s %s" % [host[1], host[3], host[5], host[0], err.class, err]

      # Prints error log
      #logger.info error_msg if $DEBUG

      # Appends log
      errors << error_msg

      total_errors += 1
    end

  end

}

# Writes temporary arry to csv file
CSV.open(FILENAME, 'w', col_sep: ';') do |csv|
  csv << HEADER
  result.map {|e| e ? e : ''} # replaces nil values
  result.each {|row| csv << row}
end

logger.info "%s rows recorded in %s." % [result.size, FILENAME]

statistics =
    "\nStatistics for #{FILENAME}\n" +
        "+#{'-' * 130}+\n" +
        "| Total checked NEs: #{job_list.size}\n" +
        "| Total errors: #{total_errors.to_s}\n" +
        "|\n| Errors:\n"
errors.each {|error| statistics << "|#{error}\n"}
statistics << "+#{'-' * 130}+\n"

print statistics

# Writes log file
File.open(LOGFILE, 'a') {|f| f.puts statistics}
logger.info "Log file %s created." % LOGFILE

# Prints total time
logger.info "Job done, total time: %0.2f seconds" % total_time
