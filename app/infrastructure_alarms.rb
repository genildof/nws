require_relative File.expand_path('reports')

# Me: Does Requires statement for all files in the current directory
# Dir[File.dirname(__FILE__) + '/*.rb'].each {|file| require file}

# todo: Keymile -> SUEN interfaces report
# todo: Keymile -> Active Ethernet interfaces report
# todo: Zhone -> uplink optical value evaluation

# https://blog.engineyard.com/2014/ruby-thread-pool
# https://github.com/meh/ruby-threadpool

#CITY_LIST = %w"LZI VPO SCQ TDA PMJ RVD ACG CPE DOS ROI CBA BSA GNA"
CITY_LIST = %w"SNE SBO MAU SVE SPO STS AUJ MCZ GRS OCO SOC VOM JAI VRP CAS IDU PAA RPO BRU ARQ"

def lets_go(cities) #cities is an array of string
  thread_list = [] #keep track of our threads

  cities.each do |city|
    thread_list << Thread.new {#add a new thread to
      t0 = Time.now
      puts "\nThread #{city} started at #{Time.now.strftime('%d-%m-%Y %H-%M-%S')}"
      puts "Generating report for #{city}"
      Reports.new.generate_report(city)
      t1 = Time.now
      time_ms = (t1 - t0) * 1000
      puts "Thread #{city} ended at #{Time.now.strftime('%d-%m-%Y %H-%M-%S')} - Time elapsed = #{time_ms}ms"
    }
  end

  thread_list.each { |x| x.join } #wait for each thread to complete

end

lets_go(CITY_LIST) #read them concurrently
