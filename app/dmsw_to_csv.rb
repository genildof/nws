require 'benchmark'
# require 'logger'
require 'csv'
require '../lib/datacom-api'
require '../lib/service'

include Service, Datacom

# ["106 B", "D2SPO06I0202", "HEADEND", "10.211.33.97", nil, "Anel Centro - Basilio da Gama", "SAO PAULO"]
HEADER = %w[SUB HOST TYPE IP CUSTOMER RING CITY Domain State Mode Port Port Ctrl_VLAN Pretected_VLANs Login_Type]
WORKERS = 5 # according to the nmc ssh gateway limitation
LOGFILE = format('../log/%s_%s.log', $PROGRAM_NAME, Time.now.strftime('%d-%m-%Y_%H-%M'))
FILENAME = format('../log/%s_%s.csv', $PROGRAM_NAME, Time.now.strftime('%d-%m-%Y_%H-%M'))
result = []
total_errors = 0
errors = []

puts format("\nProgram %s started at %s", $PROGRAM_NAME, Time.now.strftime('%d-%m-%Y_%H-%M'))

job_list = Service.get_dmsw_excel_list
puts "Hosts list loaded.\n"

print format("\nStarting (Workers: %d Tasks: %d)...", WORKERS, job_list.size)

pool = ThreadPool.new(WORKERS)

total_time = Benchmark.realtime do
  pool.process!(job_list) do |host|
    eaps_status = []
    begin
      puts "\n#{host[:type]} - HEADEND found" if host[:type] = 'HEADEND'

      # ----------------------------------------------------------------- thread
      host_time = Benchmark.realtime do
        dmsw = DMSW.new

        if dmsw.connect(host[:ip]) # 1 is the index of IP address inside de host array
          eaps_status = dmsw.get_eaps_status
          eaps_status.concat(dmsw.get_login_type.to_array)
          eaps_status = 'no eaps configured' if eaps_status.nil?
          dmsw.disconnect
          puts eaps_status.to_s
          result << host.concat(eaps_status)
        end
      end
      # ----------------------------------------------------------------- thread

      # Prints partial statistics for current host
      print format("\n%s %s %s %s -- %s -- %0.2f seconds", host[:hostname], host[:ip], host[:ring_name], host[:rub_ring], eaps_status.to_s, host_time)
    rescue StandardError => err
      error_msg = format('%s %s %s %s -- %s %s', host[:hostname], host[:ip], host[:ring_name], host[:rub_ring], err.class, err)

      # Appends log
      errors << error_msg
      total_errors += 1
    end
  end
end

# Writes temporary arry to csv file
CSV.open(FILENAME, 'w', col_sep: ';') do |csv|
  csv << HEADER
  result.map { |e| e || '' } # replaces nil values
  result.each { |row| csv << row }
end

print format("\n%s rows recorded in %s.", result.size, FILENAME)

statistics =
  "Statistics for #{FILENAME}\n" + "+#{'-' * 130}+\n" + "| Total checked NEs: #{job_list.size}\n" + "| Total errors: #{total_errors}\n" + "|\n| Errors:\n"
errors.each { |error| statistics << "|#{error}\n" }
statistics << "+#{'-' * 130}+\n"

# Writes log file
File.open(LOGFILE, 'a') { |f| f.puts statistics }
print format("\nLog file %s created.", LOGFILE)

# Prints total time
print format("\nJob done, total time: %0.2f seconds", total_time)
