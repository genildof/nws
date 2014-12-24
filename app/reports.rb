require_relative 'zhone-api'
require_relative 'keymile-api'

class Reports

  DSLAM_MODEL = [/Milegate/, /Zhone/]

  # @param [String] city
  # @return [boolean]
  def generate_report(city)

    hosts = Service::Cricket.new.get_dslam_list(city).select { |dslam|
      dslam.model.match(DSLAM_MODEL[0]) or dslam.model.match(DSLAM_MODEL[1])
    }

    # If CAS add hosts of csv list
    if city == 'CAS'
      puts 'Loading manual input file for CAS...'
      hosts = hosts.concat(Service::Input.new.get_external_list)
    end

    logfile = "../reports/#{city}_audit_#{Time.now.strftime('%d-%m-%Y_%H-%M')}.log"

    @current_host = 0
    @total_system_alarms = 0
    @total_card_alarms = 0
    @total_cards_checked = 0
    @total_redundancy_errors = 0
    @remote_access_errors = 0
    @keymile_alarms = Array.new
    @zhone_alarms = Array.new

    puts "Checking #{hosts.size} hosts for #{city} location\n"

    hosts.each { |host|

      @current_host += 1

      target = "#{host.dms_id}\tRIN #{host.rin}\t\tat #{host.ip}"
      puts "#{city}: Now on #{host.model} #{target}\t-\t#{@current_host} / #{hosts.size}"

      begin

        dslam = nil

        case host.model
          when /Milegate/
            dslam = Keymile::Milegate.new(host.ip)
          when /Zhone/
            dslam = Zhone::MXK.new(host.ip)
          else
            puts "Unknown DSLAM Model found: #{host.model} for #{city}"
        end

        dslam.connect

        # Verifies system alarms on the shelf
        system_alarms = dslam.get_system_alarms
        card_alarms = dslam.get_card_alarms
        redundancy_alarms = dslam.get_redundancy_alarms

        @total_cards_checked += dslam.get_all_cards.size
        @total_system_alarms += system_alarms.size
        @total_card_alarms += card_alarms.size
        @total_redundancy_errors += redundancy_alarms.size

        case host.model
          when /Milegate/
            system_alarms.each { |alarm| @keymile_alarms << "#{target}\t\tAlarm >> #{alarm}" }
            card_alarms.each { |alarm| @keymile_alarms << "#{target}\t\tAlarm >> #{alarm}" }
            redundancy_alarms.each { |alarm| @keymile_alarms << "#{target}\t\tAlarm >> #{alarm}" }
          when /Zhone/
            system_alarms.each { |alarm| @zhone_alarms << "#{target}\t\tAlarm >> #{alarm}" }
            card_alarms.each { |alarm| @zhone_alarms << "#{target}\t\tAlarm >> #{alarm}" }
            redundancy_alarms.each { |alarm| @zhone_alarms << "#{target}\t\tAlarm >> #{alarm}" }
        end

        dslam.disconnect

        true

      rescue => err
        puts '=' * 70
        puts "Error: #{target}"
        puts "#{err.class} #{err}"
        @remote_access_errors += 1
        case host.model
          when /Milegate/
            @keymile_alarms << "#{target}\t\tError >> No remote access"
          when /Zhone/
            @zhone_alarms << "#{target}\t\tError >> No remote access"
        end
      end
    }

    # Report
    File.open(logfile, 'a') { |f|

      f.puts "+#{'-' * 38}" + " General status for #{city} " + "#{'-' * 38}+\n|\n"
      f.puts "| Total checked NEs: #{hosts.size}"
      f.puts "| Total remote access errors: #{@remote_access_errors.to_s}"
      f.puts "| Total NE alarms: #{@total_system_alarms.to_s}"
      f.puts "| Total cards checked: #{@total_cards_checked.to_s}"
      f.puts "| Total card alarms: #{@total_card_alarms.to_s}"
      f.puts "| Total redundancy alarms: #{@total_redundancy_errors.to_s}\n|\n"
      f.puts "+#{'-' * 100}+\n|\n"
      f.puts "|\n| KEYMILE Alarms"
      @keymile_alarms.each { |alarm| f.puts "|\t#{alarm}" }
      f.puts "|\n| ZHONE Alarms"
      @zhone_alarms.each { |alarm| f.puts "|\t#{alarm}" }
      f.puts "|\n+#{'-' * 100}+"
    }

  end

end