require 'benchmark'
require 'csv'
require '../lib/service'
require '../lib/keymile-api'
require '../lib/zhone-api'
include Service, Keymile, Zhone
HEADER = %w(MODEL MSAN RIN IP TYPE ITEM DESCRIPTION PRIORITY COMMENTS)
WORKERS = 100
FILENAME = '../log/infrastructure_alarms_report_%s.csv' % Time.now.strftime('%d-%m-%Y_%H-%M')
LOGFILE = '../log/infrastructure_alarms_logfile_%s.log' % Time.now.strftime('%d-%m-%Y_%H-%M')
CITY_LIST = %w"BSA TAG GNA RVD ANS ACG CBA VAZ ROI PMJ CPE DOS"
#CITY_LIST = %w"SNE SBO MAU SVE SPO STS AUJ MCZ GRS OCO SOC VOM JAI VRP CAS IDU PAA RPO BRU ARQ"
job_list = []
result = []
total_system_alarms = 0
total_card_alarms = 0
total_cards_checked = 0
total_interface_alarms = 0





total_errors = 0





errors = []











print "Scrapping cricket page...\n"





CITY_LIST.each do |cnl|





  hosts = get_cricket_list(cnl).select do |k|





    k[:model] =~ /Zhone/ || k[:model] =~ /Milegate/





  end





  job_list.concat(hosts)





  print "\t%s: %d element(s)\n" % [cnl, hosts.size]





end





print "Done.\n"











print "\nLoading alternative imputs...\n"





job_list = job_list.concat(get_msan_csv_list)





print "Done.\n"











print "\nStarting (Workers: %d Tasks: %d)...\n\n" % [WORKERS, job_list.size]











total_time = Benchmark.realtime {











  pool = ThreadPool.new(WORKERS)



  pool.process!(job_list) do |host|











    partial_alarms = 0











    host_time = Benchmark.realtime {











      msan = nil











      case host[:model]











        when /Milegate/





          msan = Milegate.new(host[:ip])











        when /Zhone/





          msan = MXK.new(host[:ip])











      else





        puts "Unknown model %s found at %s" % [host[:model], host[:ip]]





        errors << "#{host.values} -- unknown model"





        total_errors = +1





      end











      msan.connect











      # Loads system, card and interface alarms





      system_alarms = msan.get_system_alarms





      card_alarms = msan.get_card_alarms





      interface_alarms = msan.get_interface_alarms











      # Generates statistics





      total_cards_checked += msan.get_all_cards.size





      total_system_alarms += system_alarms.size





      total_card_alarms += card_alarms.size





      total_interface_alarms += interface_alarms.size





      partial_alarms += (system_alarms.size + card_alarms.size + interface_alarms.size)











      # Concatenates host info to alarm info and appends to temporary array





      system_alarms.concat(card_alarms).concat(interface_alarms).each do |alarm|





        csv_row = host.values.concat(alarm)











        print "\t" + csv_row.to_s + "\n"











        result << csv_row





      end











      msan.disconnect











      true





    }











    # partial statistics for current host





    print "%s %s %s %s -- %0.2f seconds -- %s alarm(s)\n" %





              [host[:model], host[:dms_id], host[:rin], host[:ip], host_time, partial_alarms]











  rescue => err





    # Prints error log





    print "%s %s %s %s -- %s %s\n" % [host[:model], host[:dms_id], host[:rin], host[:ip], err.class, err]











    # Increments error counter and appends log





    errors << "%s %s %s %s -- %s %s" % [host[:model], host[:dms_id], host[:rin], host[:ip], err.class, err]





    total_errors += 1





  end











}











statistics =





    "Statistics for #{FILENAME}\n" +





        "+#{'-' * 130}+\n" +





        "| Total checked NEs: #{job_list.size}\n" +





        "| Total NE alarms: #{total_system_alarms.to_s}\n" +





        "| Total cards checked: #{total_cards_checked.to_s}\n" +





        "| Total card alarms: #{total_card_alarms.to_s}\n" +





        "| Total interface alarms: #{total_interface_alarms.to_s}\n" +





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





