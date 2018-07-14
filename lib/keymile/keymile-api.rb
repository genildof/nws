#!/usr/bin/env ruby
require 'net/telnet'

module Keymile

  class Milegate
    # Equipment constants for use on:
    # ---===### CLI Release R2A20, Build 2013-11-05 ###===---

    USERNAME = 'manager'
    USER_PW = ''
    PROMPT = /\/[$%#>]/s
    LOGIN_PROMPT = /[Ll]ogin as[: ]/
    PASSWORD_PROMPT = /[Pp]ass(?:word|phrase)[: ]/
    MAX_OPTICAL_THRESHOLD = -18
    MIN_OPTICAL_THRESHOLD = -40

    REGEX_SYSTEM_ALARM = /\[.+\n.+\n.+\n.+\n.+\n.+\n.+\n.+\n.+\n/
    REGEX_SYSTEM_ALARM_CAUSE = /\b[\w ]+\b(?=.+\bFaultCause\b)/
    REGEX_SYSTEM_ALARM_STATE = /\b\w+\b(?=.+\bFaultCauseState\b)/
    REGEX_EXTERNAL_ALARMS = /\balarm[- ].+\b/
    REGEX_INTERFACE_SUPPORT = /\b\w+\b(?=.+\bDdmInterfaceSupport\b)/
    REGEX_INTERFACE_RX_VALUE = /.\d+\b(?=.+\bRxInputPower\b)/
    REGEX_INTERFACE_STATUS = /\b\w+\b(?=.+\bState\b)/
    REGEX_CARDS = /\b\w+:.+/
    REGEX_SLOT_LINES = /\bunit[- ].+\b/ # If wants fan unit: /\b(?:fan|unit)[- ].+\b/
    REGEX_SHDSL_PORTS = /logport\W.*/ #/\logport-\w+\s(\|[\w\s\.:\?-]+){7}(.+)/
    REGEX_DSL_WITH_CAPTIONS = /\b\s\w{1,3}\W+\w+/
    REGEX_DSL_VALUES = /[\w|\W]\w.+\B\\\B/
    #REGEX_DSL_VALUES = /(Up|Down|[^\-]\d[^\/])/
    @telnet
    attr_accessor :ip_address

    def initialize(ip_address)
      super()
      self.ip_address = ip_address
    end

    # Function <tt>connect</tt> establishes connection and authenticates on Milegate MSAN.
    # @return [boolean] value
    def connect
      @telnet = Net::Telnet::new(
          'Prompt' => PROMPT,
          'Timeout' => 10,
          'Host' => self.ip_address
      ) # { |str| print str }

      @telnet.login('Name' => USERNAME, 'Password' => USER_PW,
                    'LoginPrompt' => LOGIN_PROMPT, 'PasswordPrompt' => PASSWORD_PROMPT) # { |str| print str }
      true
    end

    # Function <tt>disconnect</tt> closes the session.
    # @return [boolean] value
    def disconnect
      @telnet.close
      true
    end

    # /status> get RedundancyStatus
    #                                                                    \ # CoreUnitStatus
    # true                                                               \ # RedundantUnitPresent
    # true                                                               \ # ProtectionEnabled
    # true                                                               \ # AllComponentsSynchronised
    # true                                                               \ # EquipmentsCompatible
    # false                                                              \ # UnitsIsolated
    # /status>
    #
    # /> get /unit-11/port-1/status/DdmStatus
    # \ # DdmStatus
    # Supported                                                          \ # DdmInterfaceSupport
    # 28                                                                 \ # ModuleTemperature
    # 3.34E0                                                             \ # SupplyVoltage
    # 3.9E0                                                              \ # TxBiasCurrent
    # -5                                                                 \ # TxOutputPower
    # -5                                                                 \ # RxInputPower

    # Function <tt>get_interface_alarms</tt> gets the uplink interfaces statuses and its RxInputPower values
    # @returns default 1x4 [array] result
    def get_interface_alarms
      begin
        result = Array.new
        interfaces = Array.new

        # Find valid uplink interfaces
        self.get_cards_by_name(/COGE/).each {|slot| slot.state.match(/Ok/) ?
                                                        interfaces << "/#{slot.id}/port-1" : false}

        # For each of those interfaces...
        interfaces.each {|interface|
          admin_status = self.get_interface_admin_status(interface)

          # For administrative Up interfaces
          if admin_status.match(/Up/)
            cmd = "get #{interface}/status/DdmStatus"
            sample = ''

            @telnet.puts(cmd) #{ |str| print str }
            @telnet.waitfor('Match' => PROMPT) {|rcvdata| sample << rcvdata}

            # Does it supports DdmStatus function?
            if sample.scan(REGEX_INTERFACE_SUPPORT)[0].to_s.match(/Supported/)
              lines = sample.scan(REGEX_INTERFACE_RX_VALUE)

              # read the RxInputPower value and appends to result
              if (lines[0].to_i < MAX_OPTICAL_THRESHOLD) & (lines[0].to_i > MIN_OPTICAL_THRESHOLD)
                result << ['INTERFACE', interface, "Low RxInputPower (#{lines[0].to_s})",
                           'Critical', 'Sinal optico degradado em interface uplink ativa do MSAN']
              end

            else
              #result << 'No DdmInterfaceSupport'
            end
          else
            #result << [interface, "#{admin_status}", 'Major - interface redundante foi desabilitada']
          end
        }

        result

      end
    end

    # /> get /unit-13/port-1/main/AdministrativeStatus
    # \ # AdministrativeStatus
    # Down                                                               \ # State
    # />
    # Function <tt>get_interface_admin_status</tt> gets the interface admin status.
    # @return [string] Up or Down value
    def get_interface_admin_status (interface)
      sample = ''
      cmd = "get #{interface}/main/AdministrativeStatus"

      @telnet.puts(cmd) #{ |str| print str }
      @telnet.waitfor('Match' => PROMPT) {|rcvdata| sample << rcvdata}

      sample.scan(REGEX_INTERFACE_STATUS)[0].to_s
    end

    # /fm> get AlarmStatus
    # {                                                                  \ # AlarmStatus
    # \ # [0] #
    # "USDF"                                                           \ # Id
    # ""                                                               \ # Layer
    # "Save Of User Data Failed"                                       \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # Off                                                              \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Major                                                            \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [1] #
    # "PCSL"                                                           \ # Id
    # ""                                                               \ # Layer
    # "All Selected PETS Clock Sources Lost"                           \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # Off                                                              \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Minor                                                            \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [2] #
    # "LOSP1"                                                          \ # Id
    # ""                                                               \ # Layer
    # "Loss Of Signal On PDH Clock Source 1"                           \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # On                                                               \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Warning                                                          \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [3] #
    # "LOSP2"                                                          \ # Id
    # ""                                                               \ # Layer
    # "Loss Of Signal On PDH Clock Source 2"                           \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # On                                                               \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Warning                                                          \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [4] #
    # "LOSP3"                                                          \ # Id
    # ""                                                               \ # Layer
    # "Loss Of Signal On PDH Clock Source 3"                           \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # Off                                                              \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Warning                                                          \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [5] #
    # "LOSP4"                                                          \ # Id
    # ""                                                               \ # Layer
    # "Loss Of Signal On PDH Clock Source 4"                           \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # Off                                                              \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Warning                                                          \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [6] #
    # "TLE"                                                            \ # Id
    # ""                                                               \ # Layer
    # "NE Temperature Limit Exceeded"                                  \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # Off                                                              \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Major                                                            \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [7] #
    # "TLA"                                                            \ # Id
    # ""                                                               \ # Layer
    # "NE Temperature Limit Approaching"                               \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # Off                                                              \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Warning                                                          \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [8] #
    # "SUF"                                                            \ # Id
    # ""                                                               \ # Layer
    # "SNTP Unicast Failed"                                            \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # On                                                               \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Major                                                            \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [9] #
    # "SBF"                                                            \ # Id
    # ""                                                               \ # Layer
    # "SNTP Broadcast Failed"                                          \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # Off                                                              \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Major                                                            \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [10] #
    # "TNA"                                                            \ # Id
    # ""                                                               \ # Layer
    # "System Time Not Available"                                      \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # On                                                               \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Minor                                                            \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [11] #
    # "RSF"                                                            \ # Id
    # ""                                                               \ # Layer
    # "RADIUS Server Failed"                                           \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # Off                                                              \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Major                                                            \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [12] #
    # "HWIC"                                                           \ # Id
    # ""                                                               \ # Layer
    # "Hardware Incompatible With Configuration"                       \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # Off                                                              \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Major                                                            \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [13] #
    # "SWIC"                                                           \ # Id
    # ""                                                               \ # Layer
    # "Software Incompatible With Configuration"                       \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # Off                                                              \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Major                                                            \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [14] #
    # "GSW"                                                            \ # Id
    # ""                                                               \ # Layer
    # "General Software Alarm"                                         \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # Off                                                              \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Major                                                            \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [15] #
    # "MFA"                                                            \ # Id
    # ""                                                               \ # Layer
    # "Maintenance Function Active"                                    \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # On                                                               \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Warning                                                          \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [16] #
    # "REDCOP"                                                         \ # Id
    # ""                                                               \ # Layer
    # "CU Redundancy Communication Problem"                            \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # Off                                                              \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Major                                                            \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [17] #
    # "REDPAN"                                                         \ # Id
    # ""                                                               \ # Layer
    # "Protecting CU Active But Not Assigned"                          \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # Off                                                              \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Major                                                            \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [18] #
    # "REDPRA"                                                         \ # Id
    # ""                                                               \ # Layer
    # "Protecting CU Active"                                           \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # Off                                                              \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Major                                                            \ # Severity
    # true                                                             \ # Monitored
    # ;                                                                  \
    # }                                                                  \
    # /fm>

    # /fan/fm> get AlarmStatus
    # {                                                                  \ # AlarmStatus
    # \ # [0] #
    # "UNAV"                                                           \ # Id
    # ""                                                               \ # Layer
    # "Unit Not Available"                                             \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # On                                                               \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Critical                                                         \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [1] #
    # "UNAS"                                                           \ # Id
    # ""                                                               \ # Layer
    # "Unit Not Assigned"                                              \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # Off                                                              \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Warning                                                          \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [2] #
    # "HWIC"                                                           \ # Id
    # ""                                                               \ # Layer
    # "Hardware Incompatible With Configuration"                       \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # Off                                                              \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Major                                                            \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [3] #
    # "TBF"                                                            \ # Id
    # ""                                                               \ # Layer
    # "Total Fan Breakdown"                                            \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # Off                                                              \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Critical                                                         \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [4] #
    # "PBF"                                                            \ # Id
    # ""                                                               \ # Layer
    # "Partial Fan Breakdown"                                          \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # Off                                                              \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Minor                                                            \ # Severity
    # true                                                             \ # Monitored
    # ; \ # [5] #
    # "EQM"                                                            \ # Id
    # ""                                                               \ # Layer
    # "Equipment Malfunction"                                          \ # FaultCause
    # Off                                                              \ # FaultCauseState
    # Off                                                              \ # TrappedFaultCauseState
    # Off                                                              \ # FilteredFaultCauseState
    # Critical                                                         \ # Severity
    # true                                                             \ # Monitored
    # ;                                                                  \
    # }                                                                  \
    # /fan/fm>

    # /fan> ls -e
    # ID       | Name | Main Mode          | Equip State | Alarm Sev | Prop Alarm Sev | User Label         | Service Label | Description
    # ---------+------+--------------------+-------------+-----------+----------------+--------------------+---------------+------------
    # alarm-1  |      | Door_Open          |             | Cleared   | Cleared        | Door_Open          |               |
    # alarm-2  |      | Temperatura Alta   |             | Cleared   | Cleared        | Temperatura Alta   |               |
    # alarm-3  |      | Falha de AC        |             | Cleared   | Cleared        | Falha de AC        |               |
    # alarm-4  |      | Falha de Fan       |             | Cleared   | Cleared        | Falha de Fan       |               |
    # alarm-5  |      | Porta Equipamentos |             | Cleared   | Cleared        | Porta Equipamentos |               |
    # alarm-6  |      | Porta Fusiveis     |             | Cleared   | Cleared        | Porta Fusiveis     |               |
    # alarm-7  |      | Porta Baterias     |             | Cleared   | Cleared        | Porta Baterias     |               |
    # alarm-8  |      |                    |             | Cleared   | Cleared        |                    |               |
    # alarm-9  |      |                    |             | Cleared   | Cleared        |                    |               |
    # alarm-10 |      |                    |             | Cleared   | Cleared        |                    |               |
    # alarm-11 |      |                    |             | Cleared   | Cleared        |                    |               |
    # alarm-12 |      |                    |             | Cleared   | Cleared        |                    |               |
    # /fan>

    # Function <tt>get_system_alarms</tt> gets all the system alarms.
    # @returns default 1x4 [array] result
    def get_system_alarms
      result = Array.new
      sample = '' #can't be nil, nil is incompatible with the << assign operator
      cmds1 = ['get fm/AlarmStatus', 'get /fan/fm/AlarmStatus']
      cmds2 = ['ls /fan -e']

      cmds1.each {|cmd|
        @telnet.puts(cmd) {|str| print str}
        @telnet.waitfor('Match' => PROMPT) {|rcvdata| sample << rcvdata}
      }

      sample.scan(REGEX_SYSTEM_ALARM).each {|line|
        if line.scan(REGEX_SYSTEM_ALARM_STATE)[0].match(/On/) # If alarm is On

          alarm = line.scan(REGEX_SYSTEM_ALARM_CAUSE)[0].to_s

          msg = ''

          case alarm

          when /Partial Fan Breakdown/
            item = 'FAN tray'
            prior = 'Major'
            msg = 'Falha na bandeja de FANs do shelf'

          when /Total Fan Breakdown/
            item = 'FAN tray'
            prior = 'Critical'
            msg = 'Bandeja de FANs do shelf inoperante'

          when /NE Temperature/
            item = 'Shelf'
            prior = 'Critical'
            msg = 'Sobreaquecimento do shelf - verificar bandeja de FANs e sistema de ventilacao do armario'

          when /System Time Not Available/
            item = 'Shelf'
            prior = 'Minor'
            msg = 'Revisar ordem de prioridade das fontes de clock TDM configuradas no NE'

          when /Loss Of Signal On PDH Clock Source/
            item = 'Shelf'
            prior = 'Major'
            msg = 'LOSS em uma das fontes de sincronismo E1 TDM'

          when /Unit Not Available/
            item = 'FAN Tray'
            prior = 'Critical'
            msg = 'Bandeja de ventilacao do shelf esta inoperante'

          else
            item = 'Shelf'
            prior = 'Minor'
          end

          result << ['SYSTEM', item, alarm, prior, msg] # Add it to array

        end
      }

      sample = '' #can't be nil, nil is incompatible with the << assign operator

      cmds2.each {|cmd|
        @telnet.puts(cmd) {|str| print str}
        @telnet.waitfor('Match' => PROMPT) {|rcvdata| sample << rcvdata}
      }

      sample.scan(REGEX_EXTERNAL_ALARMS).each {|line|

        values = line.split(/\|/)
        msg = ''

        unless values[4].match(/Cleared/) #if present

          case

          when (values[2].to_s.match(/Falha de Fan/) or values[2].to_s.match(/Temperatura Alta/))
            prior = 'Critical'
            msg = 'Alarme externo de falha no do sistema de ventilacao do armario'

          else
            prior = values[4].strip!

          end

          result << ['SYSTEM', values[0].strip!, values[2].strip!, prior, msg]

        end
      }

      result
    end


    # />ls -e
    #
    # ID             | Name      | Main Mode      | Equip State | Alarm Sev | Prop Alarm Sev | User Label | Service Label | Description
    # ---------------+-----------+----------------+-------------+-----------+----------------+------------+---------------+------------
    # eoam           |           |                |             | Cleared   | Cleared        |            |               |
    # fan            | FANU4     |                | Ok          | Cleared   | Cleared        |            |               |
    # multicast      |           |                |             | Cleared   | Cleared        |            |               |
    # services       |           |                |             | Cleared   | Cleared        |            |               |
    # tdmConnections |           |                |             | Cleared   | Cleared        |            |               |
    # unit-1         |           |                | Empty       | Cleared   | Cleared        |            |               |
    # unit-2         |           |                | Empty       | Cleared   | Cleared        |            |               |
    # unit-3         |           |                | Empty       | Cleared   | Cleared        |            |               |
    # unit-4         |           |                | Empty       | Cleared   | Cleared        |            |               |
    # unit-5         |           |                | Empty       | Cleared   | Cleared        |            |               |
    # unit-6         |           |                | Empty       | Cleared   | Cleared        |            |               |
    # unit-7         |           |                | Empty       | Cleared   | Cleared        |            |               |
    # unit-8         |           |                | Empty       | Cleared   | Cleared        |            |               |
    # unit-9         |           |                | Empty       | Cleared   | Cleared        |            |               |
    # unit-10        |           |                | Empty       | Cleared   | Cleared        |            |               |
    # unit-11        | COGE1 R4D | coge1_r6c07    | Ok          | Cleared   | Cleared        |            |               |
    # unit-12        |           |                | Empty       | Cleared   | Cleared        |            |               |
    # unit-13        | COGE1 R4D | coge1_r6c07    | Ok          | Cleared   | Cleared        |            |               |
    # unit-14        |           |                | Empty       | Cleared   | Cleared        |            |               |
    # unit-15        |           |                | Empty       | Cleared   | Cleared        |            |               |
    # unit-16        |           |                | Empty       | Cleared   | Cleared        |            |               |
    # unit-17        |           |                | Empty       | Cleared   | Cleared        |            |               |
    # unit-18        |           |                | Empty       | Cleared   | Cleared        |            |               |
    # unit-19        | IPSX3 R1C | ipsm2_r6c04_01 | Ok          | Cleared   | Cleared        |            |               |
    # unit-20        | LOMI8 R1B | lomi8_r3a05    | Ok          | Cleared   | Cleared        |            |               |
    # unit-21        | STIM1 R1C | stim1_r4b04    | Ok          | Cleared   | Major          |            |               |
    # />

    # Function <tt>get_all_cards</tt> gets all the system cards and its operational status.
    # @return [array] value
    def get_all_cards

      result = Array.new
      sample = ''
      cmd = 'ls / -e'

      @telnet.puts(cmd) {|str| print str}
      @telnet.waitfor('Match' => PROMPT) {|rcvdata| sample << rcvdata}

      sample.scan(REGEX_SLOT_LINES).each {|line|
        values = line.split(/\|/).map {|e| e ? e : 0} # Replaces nil values of array

        unless values[3].to_s.match(/Empty/) # If slot is not empty
          result << Slot.new do
            self.id = values[0].strip!
            self.name = values[1].strip!
            self.main_mode = values[2].strip!
            self.state = values[3].strip!
            self.alarm = values[4].strip!
            self.prop_alarm = values[5].strip!
          end
        end
      }

      result

    end


    # Function <tt>get_card_alarms</tt> gets all not running system.
    # @return [array] value
    def get_card_alarms

      result = Array.new
      alarmed_cards = get_all_cards.select {|slot| !slot.state.to_s.match(/Ok/)}

      alarmed_cards.each do |card|
        case

        when card.name.to_s.match(/COGE/)
          prior = 'Minor'
          msg = 'Cartao nao comissionado ou desativado presente no slot'

        else
          prior = 'Critical'
          msg = 'Cartao com falha inoperante'

        end

        result << ['CARD', card.id, "#{card.name} #{card.state}", prior, msg]

      end

      result

    end


    # Function <tt>get_cards_by_name(name)</tt> gets system cards by name.
    # Depends on the function <tt>get_slots_all</tt>.
    # @return [array] value
    def get_cards_by_name(name)
      get_all_cards.select {|slot| slot.name.match(name)}
    end

    <<-NOTE
    # /unit-21/logports> ls -e
    # ID        | Name       | Main Mode | Equip State | Alarm Sev | Prop Alarm Sev | User Label                   | Service Label                | Description
    # ----------+------------+-----------+-------------+-----------+----------------+------------------------------+------------------------------+-----------------
    # logport-1 | SHDSL Span | port-1    |             | Major     | Major          | ISAMAR                       | WO:11119385                  | CAS-30YUBKP7-032
    # logport-2 | SHDSL Span | port-2    |             | Cleared   | Cleared        | Cliente: TREND_COMERCIO      | Designador: CAS-30X8KD9G-032 |
    # logport-3 | SHDSL Span | port-3    |             | Cleared   | Cleared        | Cliente: TREND COMERCIO      | Designador: CAS-30X8KDXJ     |
    # logport-4 | SHDSL Span | port-4    |             | Cleared   | Cleared        | Cliente:DIA ENTREGUE TRANSPO | Designador:CAS-301B6EQYX-032 |
    # /unit-21/logports>
    NOTE

    # Function <tt>get_shdsl_ports_all</tt> gets all shdsl ports and its labels from STIM cards.
    # @return [array] value
    def get_shdsl_ports_all (slot)
      result = Array.new
      sample = ''
      cmd = "ls /#{slot.id}/logports -e"

      @telnet.puts(cmd) {|str| print str}

      @telnet.waitfor('Match' => PROMPT) {|rcvdata| sample << rcvdata}

      sample.scan(REGEX_SHDSL_PORTS).each {|row|

        values = row.split(/\|/) #.map { |e| e || '+-+-+-+-+-+-+-+-+' } # Replaces nil values of array

        result << SHDSL_Port.new do
          self.id = values[0]
          self.name = values[1]
          self.main_mode = values[2].strip!
          self.state = values[3]
          self.alarm = values[4]
          self.prop_alarm = values[5]
          self.user_label = values[6]
          self.service_label = values[7]
          self.description = values[8]
        end
      }
      result
    end

    # /> get /unit-21/port-1/segment-1/status/SegmentStatus
    #                                                                    \ # SegmentStatus
    # Down                                                               \ # OperationalStatus
    #                                                                    \ # NearEnd
    # -128                                                               \ # CurrentAttenuation
    # 127                                                                \ # CurrentMargin
    # 255                                                                \ # CurrentPowerBackOff
    #                                                                    \ # FarEnd
    # -128                                                               \ # CurrentAttenuation
    # 127                                                                \ # CurrentMargin
    # 255                                                                \ # CurrentPowerBackOff
    # />

    # Function <tt>get_shdsl_params</tt> gets shdsl line parameters.
    # @return [array] value
    def get_shdsl_params(slot, port)

      result = Array.new
      sample = ''

      cmd = "get /#{slot.id}/#{port.main_mode}/segment-1/status/SegmentStatus"

      @telnet.puts(cmd) {|str| print str}

      @telnet.waitfor('Match' => PROMPT) {|rcvdata| sample << rcvdata}

      sample.scan(REGEX_DSL_VALUES).each do |value|
        puts value.to_s.scan(/\w+/)[0]
        result << "#{value.to_s.scan(/\w+/)[0]}"
      end

      result
    end
  end

  # slots VO
  class Slot
    attr_accessor(:id, :name, :main_mode, :state, :alarm, :prop_alarm)

    def initialize(&block)
      instance_eval &block
    end
  end

  # shdsl ports VO
  class SHDSL_Port
    attr_accessor(:id, :name, :main_mode, :state, :alarm,
                  :prop_alarm, :user_label, :service_label, :description)

    def initialize(&block)
      instance_eval &block
    end
  end

end


=begin

  class Array
    def sort_by(sym) # Own version of sort_by, from Ruby book
      self.sort { |x,y| x.send(sym) <=> y.send(sym) }
    end
  end

#'Host' => '10.211.161.53'  #CAS-A56-0
#'Host' => '10.211.161.211'  #CAS-A49-4
    regex_slots = /\b\w{4}[-]\d{1,2}/
    regex_id_type = /\b[A-Z,0-9]{5}\s\b/
    regex_hw_version = /\b[R]\d[A-Z]\b/
    regex_assigned_sw = /\b[a-z,0-9,_]{11,}/




Desenvolver

/unit-21/port-2/segment-1/main> get Labels
                                                                   \ # Labels
''                                                                 \ # Label1
''                                                                 \ # Label2
''                                                                 \ # Description
/unit-21/port-2/segment-1/main> 

/unit-21/logports/logport-2/cpe/chan-1/cfgm> get CtpConfiguration
                                                                   \ # CtpConfiguration
P12                                                                \ # LayerRate
""                                                                 \ # n
""                                                                 \ # Timeslots
{                                                                  \ # ConnectedToCtps
  \ # [0] #
                                                                   \ # ConnectedCtp
  /unit-20/port-2/chan-1                                           \ # RemoteCtp
  370                                                              \ # ConnectionIndex
  Bidirectional                                                    \ # Directionality
  zEnd                                                             \ # LocalRole
  aEndWorking                                                      \ # RemoteRole
;                                                                  \
}                                                                  \
/unit-21/logports/logport-2/cpe/chan-1/cfgm>

/unit-21/logports/logport-2/cpe/chan-1> ls
Infos of AP: /unit-21/logports/logport-2/cpe/chan-1
  Name                      : P12
  Main Mode                 :
  Equipment State           :
  Alarm Severity            : Cleared
  Propagated Alarm Severity : Cleared
  User Label                : Cliente: TREND_COMERCIO
  Service Label             : Designador: CAS-30X8KD9G-032
  Description               :

MF List:
  main
  cfgm
  status

AP List:
/unit-21/logports/logport-2/cpe/chan-1>



/tdmconnections/cfgm> ShowConnections 1 65535 unit-21 All All All '' ''
                                                                   \ # ShowConnections
{                                                                  \ # FilterSettings
  \ # [0] #
                                                                   \ # ConnectionFilter
  1                                                                \ # StartIndex
  65535                                                            \ # EndIndex
  unit-21                                                          \ # Unit
  All                                                              \ # LayerRate
  All                                                              \ # Directionality
  All                                                              \ # Protection
  ''                                                               \ # Label1
  ''                                                               \ # Label2
;                                                                  \
}                                                                  \
{                                                                  \ # Connections
  \ # [0] #
                                                                   \ # Connection
  337                                                              \ # ConnectionIndex
  /unit-20/port-1/chan-1                                           \ # CtpA-EndWorking
                                                                   \ # CtpA-EndProtecting
  /unit-21/logports/logport-1/cpe/chan-1                           \ # CtpZ-End
  P12                                                              \ # LayerRate
  ''                                                               \ # n
  Bidirectional                                                    \ # Directionality
  false                                                            \ # Protected
  'Isamar'                                                         \ # Label1
  ''                                                               \ # Label2
; \ # [1] #
                                                                   \ # Connection
  338                                                              \ # ConnectionIndex
  /unit-21/logports/logport-2/cpe/chan-1                           \ # CtpA-EndWorking
                                                                   \ # CtpA-EndProtecting
  /unit-20/port-2/chan-1                                           \ # CtpZ-End
  P12                                                              \ # LayerRate
  ''                                                               \ # n
  Bidirectional                                                    \ # Directionality
  false                                                            \ # Protected
  'Cliente: TREND_COMERCIO'                                        \ # Label1
  ''                                                               \ # Label2
; \ # [2] #
                                                                   \ # Connection
  339                                                              \ # ConnectionIndex
  /unit-21/logports/logport-3/cpe/chan-1                           \ # CtpA-EndWorking
                                                                   \ # CtpA-EndProtecting
  /unit-20/port-3/chan-1                                           \ # CtpZ-End
  P0nc                                                             \ # LayerRate
  '31'                                                             \ # n
  Bidirectional                                                    \ # Directionality
  false                                                            \ # Protected
  'Cliente: TREND COMERCIO'                                        \ # Label1
  ''                                                               \ # Label2
; \ # [3] #
                                                                   \ # Connection
  340                                                              \ # ConnectionIndex
  /unit-20/port-4/chan-1                                           \ # CtpA-EndWorking
                                                                   \ # CtpA-EndProtecting
  /unit-21/logports/logport-4/cpe/chan-1                           \ # CtpZ-End
  P12                                                              \ # LayerRate
  ''                                                               \ # n
  Bidirectional                                                    \ # Directionality
  false                                                            \ # Protected
  'Cliente:DIA ENTREGUE TRANSPO'                                   \ # Label1
  ''                                                               \ # Label2
;                                                                  \
}                                                                  \
/tdmconnections/cfgm>



/tdmconnections/cfgm> ShowCtps unit-21 All All
                                                                   \ # ShowCtps
unit-21                                                            \ # Unit
All                                                                \ # Connected
All                                                                \ # LayerRate
{                                                                  \ # FilteredCtps
  \ # [0] #
                                                                   \ # CtpSummary
  /unit-21/logports/logport-1/cpe/chan-1                           \ # Ctp
  P12                                                              \ # LayerRate
  ''                                                               \ # n
  true                                                             \ # Connected
  None                                                             \ # A-EndRoleSummary
  Bidirectional                                                    \ # Z-EndRoleSummary
  false                                                            \ # Protected
; \ # [1] #
                                                                   \ # CtpSummary
  /unit-21/logports/logport-2/cpe/chan-1                           \ # Ctp
  P12                                                              \ # LayerRate
  ''                                                               \ # n
  true                                                             \ # Connected
  Bidirectional                                                    \ # A-EndRoleSummary
  None                                                             \ # Z-EndRoleSummary
  false                                                            \ # Protected
; \ # [2] #
                                                                   \ # CtpSummary
  /unit-21/logports/logport-3/cpe/chan-1                           \ # Ctp
  P0nc                                                             \ # LayerRate
  '31'                                                             \ # n
  true                                                             \ # Connected
  Bidirectional                                                    \ # A-EndRoleSummary
  None                                                             \ # Z-EndRoleSummary
  false                                                            \ # Protected
; \ # [3] #
                                                                   \ # CtpSummary
  /unit-21/logports/logport-4/cpe/chan-1                           \ # Ctp
  P12                                                              \ # LayerRate
  ''                                                               \ # n
  true                                                             \ # Connected
  None                                                             \ # A-EndRoleSummary
  Bidirectional                                                    \ # Z-EndRoleSummary
  false                                                            \ # Protected
;                                                                  \
}                                                                  \
/tdmconnections/cfgm>



/status> get RedundancyStatus
                                                                   \ # CoreUnitStatus
true                                                               \ # RedundantUnitPresent
true                                                               \ # ProtectionEnabled
true                                                               \ # AllComponentsSynchronised
true                                                               \ # EquipmentsCompatible
false                                                              \ # UnitsIsolated
/status>


=end