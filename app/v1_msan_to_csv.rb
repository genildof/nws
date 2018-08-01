require 'benchmark'
require 'csv'
require 'thread'
require '../lib/v1-Keymile-api'
require '../lib/service'

include Service, Keymile

#["106 B", "D2SPO06I0202", "HEADEND", "10.211.33.97", nil, "Anel Centro - Basilio da Gama", "SAO PAULO"]
HEADER = %w(VENDOR HOSTNAME SLOT PORT)
WORKERS = 4 # according to the nmc ssh gateway limitation
LOGFILE = '../log/%s_%s.log' % [$0, Time.now.strftime('%d-%m-%Y_%H-%M')]
FILENAME = '../log/%s_%s.csv' % [$0, Time.now.strftime('%d-%m-%Y_%H-%M')]
result = []
total_errors = 0
errors = []
work_q = Queue.new

puts "\nProgram %s started at %s" % [$0, Time.now.strftime('%d-%m-%Y_%H-%M')]

job_list = self.get_v1_msan_excel_list
puts "Hosts list loaded.\n"

puts "\nStarting (Workers: %d Tasks: %d)...\n" % [WORKERS, job_list.size]
job_list.each{|host| work_q.push host }

total_time = Benchmark.realtime {

  configured_ports = 0

  workers = (0...WORKERS).map do |worker_id|

    Thread.new do

      ssh_session = self.create_ssh_session
      puts "SSH session ##{worker_id} created."

      while host = work_q.pop(true)

        host_time = Benchmark.realtime {

          puts "Machine #%s is working now on %s - queue size %s" % [worker_id, host[:hostname], work_q.size] #Thread.current

          msan = nil

          case host[:vendor]

            when /Keymile/
            msan = Milegate.new(ssh_session)

            when /Huawei/
            #msan = Zhone::MXK.new(host[:ip])

            when /Nokia/

          else
            error_msg = "Unknown vendor %s found at %s" % [host[:vendor], host[:hostname]]
            errors << error_msg
            printf "\r" + error_msg
            total_errors = +1
          end

          if msan.connect(host[:hostname])
            puts "Connected OK, disconnecting..."
            sleep (1)
            msan.disconnect
            puts "Disconnected."
          end


=begin
        # Iterates over each active shdsl port in the shelf
        msan.get_shdsl_ports_all(slot).each do |port|

          # Concatenates host, slot and port data to current csv row
          csv_row = host.values.concat(slot.to_array).concat(port.to_array)

          # Concatenates collected snr and attenuation data of current port
          msan.get_shdsl_params(slot, port).each do |shdsl_params|
            csv_row << shdsl_params
          end
        end

        print "\t" + csv_row.to_s + "\n"

        # Appends to temporary array
        result << csv_row

        # Increments port counter
        configured_ports += 1

=end

        } #host_time

        puts "Machine #%s finished -- %0.2f seconds" % [worker_id, host_time]

      end #while host

      self.close_ssh_session (ssh_session)
      puts "SSH session ##{worker_id} gracefully closed."

    rescue => err

      error_msg = "%s %s -- %s %s" % [host[:vendor], host[:hostname], err.class, err]
      errors << error_msg
      printf "\r%s" % error_msg
      total_errors += 1

    end #Thread


  end; "ok" #workers = (0...WORKERS).map

  workers.map(&:join); "ok"

} #total_time

# Writes temporary arry to csv file
CSV.open(FILENAME, 'w', col_sep: ';') do |csv|
  csv << HEADER
  result.map {|e| e ? e : ''} # replaces nil values
  result.each {|row| csv << row}
end

puts "\n%s rows recorded in %s." % [result.size, FILENAME]

statistics =
    "\nStatistics for #{FILENAME}\n" +
        "+#{'-' * 130}+\n" +
        "| Total checked NEs: #{job_list.size}\n" +
        "| Total errors: #{total_errors.to_s}\n" +
        "|\n| Errors:\n"
errors.each {|error| statistics << "|#{error}\n"}
statistics << "+#{'-' * 130}+\n"

# Writes log file
File.open(LOGFILE, 'a') {|f| f.puts statistics}
puts "Log file %s created." % LOGFILE

# Prints total time
puts "Job done, total time: %0.2f seconds\n" % total_time
