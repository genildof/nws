require 'benchmark'
require 'csv'
require '../lib/datacom-api'
require '../lib/service'
include Service, Datacom

# ["106 B", "D2SPO06I0202", "HEADEND", "10.211.33.97", nil, "Anel Centro - Basilio da Gama", "SAO PAULO"]
HEADER = %w[SUB HOST TYPE IP CUSTOMER RING CITY ID Domain State Mode Port Port Ctrl_VLAN Protected_VLANs Login_Type]
LOGFILE = format('../log/%s_%s.log', $PROGRAM_NAME, Time.now.strftime('%d-%m-%Y_%H-%M'))
FILENAME = format('../log/%s_%s.csv', $PROGRAM_NAME, Time.now.strftime('%d-%m-%Y_%H-%M'))
WORKERS = 10 # according to the nmc ssh gateway limitation
@total_errors = 0
@errors = []
@result = []
work_q = Queue.new
Thread.abort_on_exception = true

# returns retry_q
def process_queue(queue, retrying)

  retry_q = Queue.new
  workers = (0...WORKERS).map do |worker_id|

    Thread.new do

      ssh_session = create_ssh_session
      print "\nMachine ##{worker_id} - SSH session created."

      while queue.size > 0
        host = queue.pop
        eaps_status = []
        execution = 'NOT done'

        host_time = Benchmark.realtime do
          print "\nMachine #%s is working now on %s - work_q size %s - retry_q size %s" % [worker_id, host[:hostname], queue.size, retry_q.size] # Thread.current
          dmsw = DMSW.new ssh_session
          begin
              if dmsw.connect(host, retrying)
              eaps_status = host.values.concat(dmsw.get_eaps_status).concat(retrying ? ['vendor'] : ['radius'])
              @result << eaps_status
              execution = 'done'
              dmsw.disconnect
            elsif !retrying
              # Store host for second attempt
              retry_q.push host
            end
          rescue Exception => err
            error_msg = format('Machine #%s on %s -- %s', worker_id, host[:hostname], err.inspect)
            print "\n%s" % error_msg
            @errors << error_msg
            @total_errors += 1
          end
        end

        # Prints partial statistics for current host
        print "\nMachine #%s job [ %s ] on %s -- [ %s ] -- %0.2f seconds" % [worker_id, execution, host[:hostname], eaps_status[9], host_time]
      end

      close_ssh_session ssh_session
      print "\nMachine ##{worker_id} - SSH session gracefully closed."

    end
  end

  workers.map(&:join); 'ok' # Kill off each thread now that they're idle and exit
  workers.each(&:exit)
  retry_q

end

total_time = Benchmark.realtime do
  puts format("\nProgram %s started at %s", $PROGRAM_NAME, Time.now.strftime('%d-%m-%Y_%H-%M'))

  get_dmsw_excel_list.each { |host| work_q.push host }
  puts "Hosts list loaded."

  print format("\nStarting (Workers: %d Tasks: %d)...", WORKERS, work_q.size)
  retry_q = process_queue work_q, false

  print format("\nRetrying with vendor password (Workers: %d Tasks: %d)...", WORKERS, retry_q.size)
  process_queue retry_q, true if retry_q.size > 0  # Writes temporary arry to csv file

  CSV.open(FILENAME, 'w', col_sep: ';') do |csv|
    csv << HEADER
    @result.map { |e| e || '' } # replaces nil values
    @result.each { |row| csv << row }
  end

  print format("\n%s rows recorded in %s.", @result.size, FILENAME)

  statistics =  "Statistics for #{FILENAME}\n" +
                "+#{'-' * 130}+\n" +
                "| Total checked NEs: #{work_q.size}\n" +
                "| Total errors: #{@total_errors}\n" +
                "|\n| Errors:\n"
  @errors.each { |error| statistics << "|#{error}\n" }
  statistics << "+#{'-' * 130}+\n"  # Writes log file
  File.open(LOGFILE, 'a') { |f| f.puts statistics }
  print format("\nLog file %s created.", LOGFILE)
end

# Prints total time
print format("\nJob done, total time: %0.2f seconds", total_time)
Process.exit(0)
