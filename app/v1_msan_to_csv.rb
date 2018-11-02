require 'benchmark'
require 'csv'
require '../lib/v1-Keymile-api'
require '../lib/service'
include Service, Keymile

# ["106 B", "D2SPO06I0202", "HEADEND", "10.211.33.97", nil, "Anel Centro - Basilio da Gama", "SAO PAULO"]
HEADER = %w[MODEL HOSTNAME Slot_ID Slot_Name Slot_Main_Mode Slot_State Slot_Alarm Slot_Prop_Alarm
            Port_ID Port_Main_Mode Port_Alarm Port_User_Label Port_Service_Label Port_Description
            PORT_1_STATUS PORT_2_STATUS PORT_3_STATUS PORT_4_STATUS].freeze
LOGFILE = format('../log/%s_%s.log', $PROGRAM_NAME, Time.now.strftime('%d-%m-%Y_%H-%M'))
FILENAME = format('../log/%s_%s.csv', $PROGRAM_NAME, Time.now.strftime('%d-%m-%Y_%H-%M'))
WORKERS = 8 # according to the nmc ssh gateway limitation
@result = []
@total_errors = 0
@errors = []
work_q = Queue.new

def process_queue(queue)
  configured_ports = 0
  workers = (0...WORKERS).map do |worker_id|
   Thread.new do
      ssh_session = create_ssh_session
      puts "SSH session ##{worker_id} created."
      while host = queue.pop(true)
        host_time = Benchmark.realtime do
          puts format('Machine #%s is working now on %s - queue size %s', worker_id, host[:hostname], queue.size) # Thread.current
          shdsl_card_name = ''
          msan = nil

          case host[:vendor]
            when /Keymile/
              msan = Milegate.new ssh_session
                    shdsl_card_name = /SUSE1/
            when /Huawei/
              # msan = Zhone::MXK.new(host[:ip])

            when /Nokia/

            else
              error_msg = format('Unknown vendor %s found at %s', host[:vendor], host[:hostname])
              @errors << error_msg
              printf "\r" + error_msg
              @total_errors = +1
          end

          begin
            if msan.connect(host[:hostname])

              puts 'Connected OK, disconnecting...'
              # Iterates over each shdsl card found

              msan.get_cards_by_name(shdsl_card_name).each do |slot|
                # Iterates over each active shdsl port in the shelf

                msan.get_shdsl_ports_all(slot).each do |logport|
                  # Concatenates host, slot and port data to current csv row
                  csv_row = host.values.concat(slot.values).concat(logport.values)

                  # Concatenates collected snr and attenuation data of current port

                  logport[:main_mode].scan(/\b\d{1,2}\b/).each do |port|
                    msan.get_shdsl_params(slot, port).each do |shdsl_params|
                      csv_row << shdsl_params
                    end
                  end

                  # print "\t" + csv_row.to_s + "\n"
                  # Appends to temporary array
                  @result << csv_row

                  # Increments port counter
                  configured_ports += 1

                end

              end

              msan.disconnect
              puts 'Disconnected.'

            end # msan.get_cards_by_name

          rescue => err
            error_msg = "%s %s -- %s %s" % [host[:vendor], host[:hostname], err.class, err]
            @errors << error_msg
            printf "\r%s" % error_msg
            @total_errors += 1
          end

        end # host_time

        puts format('Machine #%s finished -- %0.2f seconds', worker_id, host_time)

      end # while host

      close_ssh_session ssh_session
      puts "SSH session ##{worker_id} gracefully closed."

    end # Thread
  end; 'ok' # workers = (0...WORKERS).map

  workers.map(&:join); 'ok'

end

total_time = Benchmark.realtime do
  puts format("\nProgram %s started at %s", $PROGRAM_NAME, Time.now.strftime('%d-%m-%Y_%H-%M'))
  get_v1_msan_excel_list.each { |host| work_q.push host }

  puts "Hosts list loaded.\n"
  puts format("\nStarting (Workers: %d Tasks: %d)...\n", WORKERS, work_q.size)

  process_queue work_q

  # Writes temporary arry to csv file
  CSV.open(FILENAME, 'w', col_sep: ';') do |csv|
    csv << HEADER
    @result.map { |e| e || '' } # replaces nil values
    @result.each { |row| csv << row }

  end
  puts format("\n%s rows recorded in %s.", @result.size, FILENAME)

  statistics =
  "Statistics for #{FILENAME}\n" + "+#{'-' * 130}+\n" +
    "| Total checked NEs: #{job_list.size}\n" +
    "| Total errors: #{@total_errors}\n" +
    "|\n| Errors:\n"

  @errors.each { |error| statistics << "|#{error}\n" }

  statistics << "+#{'-' * 130}+\n"

  # Writes log file
  File.open(LOGFILE, 'a') { |f| f.puts statistics }
  puts format('Log file %s created.', LOGFILE)

end # total_time

# Prints total time
puts format("Job done, total time: %0.2f seconds\n", total_time)

Process.exit(0)