require 'benchmark'
# require 'logger'
require 'csv'
require '../lib/datacom-api'
require '../lib/service'

include Service, Datacom

# ["106 B", "D2SPO06I0202", "HEADEND", "10.211.33.97", nil, "Anel Centro - Basilio da Gama", "SAO PAULO"]
HEADER = %w[SUB HOST TYPE IP CUSTOMER RING CITY ID Domain State Mode Port Port Ctrl_VLAN Protected_VLANs Login_Type]
LOGFILE = format('../log/%s_%s.log', $PROGRAM_NAME, Time.now.strftime('%d-%m-%Y_%H-%M'))
FILENAME = format('../log/%s_%s.csv', $PROGRAM_NAME, Time.now.strftime('%d-%m-%Y_%H-%M'))
WORKERS = 2 # according to the nmc ssh gateway limitation

result = []
total_errors = 0
errors = []
work_q = Queue.new

puts format("\nProgram %s started at %s", $PROGRAM_NAME, Time.now.strftime('%d-%m-%Y_%H-%M'))

job_list = Service.get_dmsw_excel_list
puts "Hosts list loaded.\n"

print format("\nStarting (Workers: %d Tasks: %d)...", WORKERS, job_list.size)
job_list.each { |host| work_q.push host }

total_time = Benchmark.realtime do
  workers = (0...WORKERS).map do |worker_id|
    Thread.new do

      ssh_session = Datacom.create_ssh_session
      puts "SSH session ##{worker_id} created."

      while host = work_q.pop(true)

        eaps_status = []

        puts "\n#{host[:ip]} - HEADEND found" if host[:type] = 'HEADEND'

        host_time = Benchmark.realtime do
          puts format('Machine #%s is working now on %s - queue size %s', worker_id, host[:hostname], work_q.size) # Thread.current

          dmsw = DMSW.new ssh_session

          if dmsw.connect(host[:ip]) # 1 is the index of IP address inside de host array
            puts 'Connected OK, processing...'
            eaps_status = dmsw.get_eaps_status
            eaps_status.concat([dmsw.get_login_type])
            eaps_status = 'No EAPS' if eaps_status.nil?
            dmsw.disconnect
            puts 'Disconnected.'
            result << host.values.concat(eaps_status)
          end

        end

        # Prints partial statistics for current host
        print format('Machine #%s finished -- %s -- %s -- %0.2f seconds', worker_id, host[:hostname], eaps_status.to_s, host_time)
      end

#     rescue StandardError => err
#       error_msg = format('%s %s -- %s %s', host[:hostname], host[:ip], err.class, err)
#      print format "\n%s" % error_msg
#       # Appends log
#       errors << error_msg
#       total_errors += 1
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
