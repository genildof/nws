#encoding: utf-8

require 'benchmark'
require 'csv'
require '../lib/service'
require '../lib/keymile-api'

include Service, Keymile

HEADER = %w(MODEL MSAN RIN IP Slot_ID Slot_Name Slot_Main_Mode Slot_State Slot_Alarm Slot_Prop_Alarm
              Port_ID Port_Main_Mode Port_Alarm Port_User_Label Port_Service_Label Port_Description
              OperationalStatus NearEnd_CurrentAttenuation NearEnd_CurrentMargin NearEnd_CurrentPowerBackOff
              FarEnd_CurrentAttenuation FarEnd_CurrentMargin FarEnd_CurrentPowerBackOff)

WORKERS = 100
DSLAM_MODEL = /Milegate/
SHDSL_CARD_NAME = /STIM/
LOGFILE = '../log/shdsl_ports_logfile_%s.log' % Time.now.strftime('%d-%m-%Y_%H-%M')
FILENAME = '../log/shdsl_ports_report_%s.csv' % Time.now.strftime('%d-%m-%Y_%H-%M')

# CITY_LIST = %w"BSA TAG GNA RVD ANS ACG CBA VAZ ROI PMJ CPE DOS"
CITY_LIST = %w"SNE SBO MAU SVE SPO STS AUJ MCZ GRS OCO SOC VOM JAI VRP CAS IDU PAA RPO BRU ARQ"

job_list = []
result = []
total_errors = 0
errors = Array.new
debugging = false

print "Scrapping cricket page...\n"
CITY_LIST.each do |cnl|
  hosts = get_cricket_list(cnl).select {|k, v| k[:model] =~ DSLAM_MODEL}
  job_list.concat(hosts)
  print "\t%s: %d element(s)\n" % [cnl, hosts.size]
end
print "Done.\n"

print "\nLoading alternative inputs..."
job_list = job_list.concat(self.get_msan_csv_list)
print "Done.\n"

print "\nStarting (Workers: %d Tasks: %d)...\n\n" % [WORKERS, job_list.size]

total_time = Benchmark.realtime {

  pool = ThreadPool.new(WORKERS)
  
  pool.process!(job_list) do |host|
    configured_ports = 0

    # ----------------------------------------------------------------- thread
    host_time = Benchmark.realtime {
      msan = Keymile::Milegate.new(host[:ip])
      msan.connect

      # Iterates over each shdsl card found
      msan.get_cards_by_name(SHDSL_CARD_NAME).each do |slot|

        # Iterates over each active shdsl port in the shelf
        msan.get_shdsl_ports_all(slot).each do |port|

          # Concatenates host, slot and port data to current csv row
          csv_row = host.values.concat(slot.to_array).concat(port.to_array)

          # Concatenates collected snr and attenuation data of current port
          msan.get_shdsl_params(slot, port).each do |shdsl_params|
            csv_row << shdsl_params
          end

          if debugging
            print "\t" + csv_row.to_s + "\n"
          end

          # Appends to temporary array
          result << csv_row

          # Increments port counter
          configured_ports += 1

        end

      end

      msan.disconnect

    }
    # ----------------------------------------------------------------- thread

    # Prints partial statistics for current host
    print "\t%s %s %s %s -- %0.2f seconds -- %s configured port(s)\n" %
              [host[:model], host[:dms_id], host[:rin], host[:ip], host_time, configured_ports]
  rescue => err
    # Prints error log
    print "\t%s %s %s %s -- %s %s\n" % [host[:model], host[:dms_id], host[:rin], host[:ip], err.class, err]
    # Increments error counter and appends log
    errors << "%s %s %s %s -- %s %s" % [host[:model], host[:dms_id], host[:rin], host[:ip], err.class, err]
    total_errors += 1
  end
}

statistics =
    "Statistics for #{FILENAME}\n" +
        "+#{'-' * 130}+\n" +
        "| Total checked NEs: #{job_list.size}\n" +
        "| Total errors: #{total_errors.to_s}\n" +
        "|\n| Errors:\n"
errors.each {|error| statistics << "|#{error}\n"}
statistics << "+#{'-' * 130}+\n"
print "\n" + statistics

print "\nWriting data rows to log file...\n"

# Writes temporary arry to csv file
CSV.open(FILENAME, 'w', col_sep: ';') do |csv|
  csv << HEADER
  result.map {|e| e ? e : ''} # replaces nil values
  result.each {|row| csv << row}
end

print "%s rows recorded in %s.\n" % [result.size, FILENAME]

# Writes log file
File.open(LOGFILE, 'a') {|f| f.puts statistics}
print "\nLog file %s created.\n" % LOGFILE

# Prints total time
print "\nJob done, total time: %0.2f seconds\n" % total_time