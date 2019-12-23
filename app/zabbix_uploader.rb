require 'roo'
require 'benchmark'
require 'zabbixapi'

def get_excel_list
    filename = '../config/BasePlus_Sigres_ate_030419.xlsx'
    xlsx = Roo::Spreadsheet.open(filename)
    sheet = xlsx.sheet(0)
    sheet.parse(nrc: 'nrc', nro_telefone13: 'nro_telefone13', ip_fixo: 'ip_fixo',
        nome_rede_olt: 'nome_rede_olt', cluster: 'Cluster')
end

puts 'Connecting to Zabbix...'
zbx = ZabbixApi.connect(
  :url => 'http://201.28.110.2/zabbix/api_jsonrpc.php',
  :user => 'Admin',
  :password => 'genildof'
)
puts 'Ok.'


total_time = Benchmark.realtime do
    work_q = Queue.new

    puts format("\nProgram %s started at %s", $PROGRAM_NAME, Time.now.strftime('%d-%m-%Y_%H-%M'))

    puts "\nStarting spreadsheet loading..."

    get_excel_list.each { |host| work_q.push host }
    print format("\n%d host(s) found.", work_q.size)

    puts "\nCreating hosts..."
    
    while work_q.size > 0
        host = work_q.pop
		
		puts "Host " + host[:nome_rede_olt].to_s + "_" + host[:nro_telefone13].to_s
				
		zbx.hosts.create_or_update(
 			:host => host[:nome_rede_olt].to_s + "_" + host[:nro_telefone13].to_s,
			:name => host[:cluster].to_s + "_" + host[:nrc].to_s,
  			:interfaces => [
    			{
      				:type => 1,
      				:main => 1,
      				:ip => host[:ip_fixo].to_s,
      				:port => 10050,
      				:useip => 0
    			}
  			],
  			:groups => [ :groupid => zbx.hostgroups.get_id(:name => host[:cluster].to_s) ],
  			:templates => [ :templateid => zbx.templates.get_id(:name => 'CPE_B2C') ]
		)
        
    end
end

zbx.logout

# Prints total time
puts format("\nJob done, total time: %0.2f seconds\n", total_time.to_s)

Process.exit(0)