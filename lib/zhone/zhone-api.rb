require 'net/telnet'

module Zhone

  class MXK

    # Session's constants for Zhone MXK
    USERNAME = 'admin'
    USER_PW = 'zhone'
    PROMPT = /zSH[$%#>]/s
    LOGIN_PROMPT = /[Ll]ogin[: ]/
    PASSWORD_PROMPT = /[Pp]ass(?:word|phrase)[: ]/

    # Detection patterns's constants for Zhone MXK
    REGEX_ALARM = /\bsystem.+/
    REGEX_INTERFACE = /\b(?:Primary|Secondary).+\b/
    REGEX_CARDS = /\b\w+:.+/

    @telnet
    attr_accessor :ip_address

    def initialize(ip_address)
      super()
      self.ip_address = ip_address
    end

    # Function <tt>connect</tt> establishes the socket connection and session.
    # @return [boolean] value
    def connect
      begin
        @telnet = Net::Telnet::new(
            'Prompt' => PROMPT,
            'Timeout' => 10,
            'Host' => self.ip_address
        ) # { |str| print str }

        @telnet.login('Name' => USERNAME, 'Password' => USER_PW,
                      'LoginPrompt' => LOGIN_PROMPT, 'PasswordPrompt' => PASSWORD_PROMPT) # { |str| print str }
        true
      end
    end

    # Function <tt>disconnect</tt> closes the session.
    # @return [boolean] value
    def disconnect
      @telnet.close
      true
    end

    # Function <tt>get_system_alarms</tt> gets all the system alarms.
    # @returns default 1x4 [array] result
    def get_system_alarms
      begin
        result = Array.new
        sample = ''

        cmd = 'alarm show'

        # sends cmd to host
        @telnet.puts(cmd) {|str| print str}

        # waits for cli prompt and stores returned data into sample variable
        @telnet.waitfor('Match' => PROMPT) {|rcvdata| sample << rcvdata}

        # zSH> alarm show
        #
        # ************    Central Alarm Manager    ************
        # ActiveAlarmCurrentCount         :1
        # AlarmTotalCount                 :11
        # ClearAlarmTotalCount            :10
        # OverflowAlarmTableCount         :0
        #
        # ResourceId                AlarmType                                 AlarmSeverity
        # ----------                ---------                                 -------------
        # system                    power_supply_a_failure                       minor
        # zSH>

        # stores alarms's rows
        sample.scan(REGEX_ALARM).each {|row|
          description = row.split(/\s+/)[1]

          # defines better information according the alarm type
          case description

          when /fan_speed_error/
            item = 'FAN tray'
            prior = 'Critical'
            msg = 'Falha na bandeja de FANs do shelf'

          when /temp_over_limit/
            item = 'FAN tray'
            prior = 'Critical'
            msg = 'Sobreaquecimento do shelf - verificar bandeja de FANs e sistema de ventilacao do armario'

          else
            item = 'Shelf'
            prior = 'Minor'
            msg = ''

          end

          result << [item, description, prior, msg]
        }
        result

      end
    end

    # Function <tt>get_interface_alarms</tt> gets the controller cards redundancy status.
    # @returns default 1x4 [array] result
    def get_interface_alarms
      begin
        result = Array.new
        sample = ''

        cmd = 'line-red show 1-a-2-0/eth'

        # sends cmd to host
        @telnet.puts(cmd) {|str| print str}

        # waits for cli prompt and stores returned data into sample variable
        @telnet.waitfor('Match' => PROMPT) {|rcvdata| sample << rcvdata}
        # zSH> line-red show 1-a-2-0/eth
        #
        # redundancy status for 1-a-2-0/eth:
        #          NOREBOOT standbytx DISABLE timeout 0 NONREVERTIVE revert timeout 0
        #
        # Interface-Type          Interface-Name        Oper-State Oper-Status
        # ============== ============================== ========== ============
        # Primary        1-a-2-0/eth                    Standby    Trfc-Disable
        # Secondary      1-b-2-0/eth                    Active     UP
        #
        # zSH>

        # stores up-link interfaces's rows
        interfaces = sample.scan(REGEX_INTERFACE)

        interfaces.each {|row|

          # splits interface's rows into columns
          columns = row.split(/\s+/)

          # filters by status column
          unless columns[2].to_s.match(/Active/) or columns[2].to_s.match(/Standby/)

            # stores data into an 4x1 array and appends it to result variable
            result << [columns[1].strip!, "#{columns[0].strip!} #{columns[3].strip!}", 'Minor', '']
          end
        }

        result
      end
    end

    # Function <tt>get_all_cards</tt> gets all the system cards and its operational status.
    # @returns default 1x2 [array] result
    def get_all_cards
      begin
        result = Array.new
        sample = ''
        cmd = 'slots'

        # sends cmd to host
        @telnet.puts(cmd) {|str| print str}

        # waits for cli prompt and stores returned data into sample variable
        @telnet.waitfor('Match' => PROMPT) {|rcvdata| sample << rcvdata}
        # zSH> slots
        #
        # MXK 823
        #
        # Uplinks
        # a:*MXK FOUR GIGE (RUNNING)
        # b: MXK FOUR GIGE (RUNNING+TRAFFIC)
        #
        # Cards
        # 1: MXK 72 PORT POTS (RUNNING)
        # 2: MXK 24 PORT VDSL2 POTS (RUNNING)
        # 3: MXK 24 PORT VDSL2 POTS (RUNNING)
        # 4: MXK 24 PORT VDSL2 POTS (RUNNING)
        # 5: MXK 24 PORT VDSL2 POTS (RUNNING)
        # 6: MXK 24 PORT VDSL2 POTS (RUNNING)
        # 7: MXK 24 PORT VDSL2 POTS (RUNNING)
        # 8: MXK 24 PORT VDSL2 POTS (RUNNING)
        # 9: MXK 24 PORT VDSL2 POTS (RUNNING)
        # 10: MXK 24 PORT VDSL2 POTS (RUNNING)
        # 11: MXK 24 PORT VDSL2 POTS (RUNNING)
        # 12: MXK 24 PORT VDSL2 POTS (RUNNING)
        # 13: MXK 24 PORT VDSL2 POTS (RUNNING)
        # 14: MXK 24 PORT VDSL2 POTS (RUNNING)
        # 15: MXK 24 PORT VDSL2 POTS (RUNNING)
        # zSH>

        # stores cards's rows
        cards = sample.scan(REGEX_CARDS)

        cards.each do |row|
          # 9: MXK 24 PORT VDSL2 POTS (RUNNING)
          # splits card's rows into an 2x1 array line and appends it to result variable
          # 1st item - card type: "9: MXK 24 PORT VDSL2 POTS"
          # 2nd item - card status: "RUNNING"
          result << [row.scan(/\b.+\s\B/)[0].strip!,
                     row.scan(/\B\(.+\)\B/)[0].scan(/\w+/)[0]] #1st scan scraps card's status, 2nd cleans the parentheses
        end

        result
      end

    end


    # Function <tt>get_card_alarms</tt> gets all not running system cards.
    # @returns default 1x4 [array] result
    def get_card_alarms
      result = Array.new

      alarmed_cards = get_all_cards.select {|slot| !slot[1].to_s.match(/RUNNING/)}

      alarmed_cards.each {|card|
        case
        when (card[1].to_s.match(/NOT_PROV/) or card[1].match(/RESET/))
          prior = 'Minor'
          msg = 'Cartao nao comissionado ou desativado presente no slot'
        else
          prior = 'Critical'
          msg = 'Cartao com falha inoperante'
        end
        result << [card[0], card[1], prior, msg]
      }
      result
    end

  end # MXK Class

end # Module