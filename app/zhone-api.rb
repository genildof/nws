require_relative 'service'
require 'net/telnet'

module Zhone

  class MXK

    # Session constants for Zhone MXK
    USERNAME = 'admin'
    USER_PW = 'zhone'
    PROMPT = /zSH[$%#>]/s
    LOGIN_PROMPT = /[Ll]ogin[: ]/
    PASSWORD_PROMPT = /[Pp]ass(?:word|phrase)[: ]/

    # Detection patterns constants for Zhone MXK
    REGEX_ALARM = /\bsystem.+/
    REGEX_REDUNDANCY = /\b(?:Primary|Secondary).+\b/
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
            'Timeout' => 20,
            'Host' => self.ip_address
        ) # { |str| print str }

        @telnet.login('Name' => USERNAME, 'Password' => USER_PW,
                      'LoginPrompt' => LOGIN_PROMPT, 'PasswordPrompt' => PASSWORD_PROMPT) # { |str| print str }
        true
      rescue => err
        puts "#{err.class} #{err}"
      end
    end

    # Function <tt>disconnect</tt> closes the session.
    # @return [boolean] value
    def disconnect
      begin
        @telnet.close
      rescue => err
        puts "#{err.class} #{err}"
      end
      true
    end

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

# Function <tt>get_alarms</tt> gets all the system alarms.
# @return [array] value

    def get_system_alarms
      begin
        result = Array.new
        sample = ''
        cmd = 'alarm show'

        @telnet.puts(cmd) { |str| print str }
        @telnet.waitfor('Match' => PROMPT) { |rcvdata| sample << rcvdata }

        sample.scan(REGEX_ALARM).each { |line|
          error_msg = line.split(/\s+/)
          result << "#{error_msg[1]}"
        }
        result
      rescue => err
        puts "#{err.class} #{err}"
      end
    end


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

# Function <tt>get_redundancy_status</tt> gets the controller cards redundancy status.
# @return [array] value
    def get_redundancy_alarms
      begin
        result = Array.new
        sample = ''
        cmd = 'line-red show 1-a-2-0/eth'

        @telnet.puts(cmd) { |str| print str }
        @telnet.waitfor('Match' => PROMPT) { |rcvdata| sample << rcvdata }
        lines = sample.scan(REGEX_REDUNDANCY)

        lines.each { |line|
          columns = line.split(/\s+/)
          unless columns[2].to_s.match(/Active/) or columns[2].to_s.match(/Standby/)
            result << "#{columns[0]} - #{columns[1]} - #{columns[3]}"
          end
        }

        result
      rescue => err
        puts "#{err.class} #{err}"
      end
    end

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

# Function <tt>get_cards_status</tt> gets all the system cards and its operational status.
# @return [array] value

    def get_all_cards
      begin
        result = Array.new
        sample = ''
        cmd = 'slots'

        @telnet.puts(cmd) { |str| print str }
        @telnet.waitfor('Match' => PROMPT) { |rcvdata| sample << rcvdata }

        lines = sample.scan(REGEX_CARDS)

        lines.each do |line|
          fields = Array.new

          fields[0] = line.scan(/\b\w+:.+\s\B/)[0]
          fields[1] = line.scan(/\B\(.+\)\B/)[0]

          result << fields
        end
        result
      rescue => err
        puts "#{err.class} #{err}"
      end
    end


# Function <tt>alarmed_cards</tt> gets all not running system cards.
# @return [array] value

    def get_card_alarms
      get_all_cards.select { |line| !line[1].to_s.match(/RUNNING/) }
    end

  end # MXK Class

end # Module
