
require 'roo'
require 'benchmark'

def get_excel_list
    filename = '../config/BasePlus_Sigres_ate_030419.xlsx'
    xlsx = Roo::Spreadsheet.open(filename)
    sheet = xlsx.sheet(0)
    sheet.parse(nrc: 'nrc', nro_telefone13: 'nro_telefone13', ip_fixo: 'ip_fixo',
        nome_rede_olt: 'nome_rede_olt', cluster: 'Cluster')
end

total_time = Benchmark.realtime do
    work_q = Queue.new

    puts format("\nProgram %s started at %s", $PROGRAM_NAME, Time.now.strftime('%d-%m-%Y_%H-%M'))

    puts "\nStarting spreadsheet loading..."

    get_excel_list.each { |host| work_q.push host }
    print format("\n%d host(s) found.", work_q.size)

    puts "\nGenerating CFG files..."
    
    while work_q.size > 0
        host = work_q.pop

        filename = format('../log/base_cfg/%s_%s.cfg', host[:cluster].to_s, host[:nrc].to_s)
        file_content = 
        "define host {" +
            "\n\tuse\t\t\tlinux-server" +
            "\n\thost_name\t\t" + host[:cluster].to_s + "_" + host[:nrc].to_s +
            "\n\talias\t\t\t" + host[:nome_rede_olt].to_s + "_" + host[:nro_telefone13].to_s +
            "\n\taddress\t\t\t" + host[:ip_fixo].to_s +
            "\n\tmax_check_attempts\t" + "5" +
            "\n\tcheck_period\t\t" + "24x7" +
            "\n\tnotification_interval\t" + "30" +
            "\n\tnotification_period\t" + "24x7" + 
        "\n}"
        
        File.open(filename, 'a') { |f| f.puts file_content }
        print format("\n---------> Log file %s created.", filename)
    end
end

# Prints total time
puts format("\nJob done, total time: %0.2f seconds\n", total_time.to_s)

Process.exit(0)