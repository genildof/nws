require 'net/ssh/telnet'

module Keymile
  JUMPSRV = '200.204.1.4'.freeze
  JUMPSRV_USER = 'r101521'.freeze
  JUMPSRV_PW = 'guerr@01'.freeze

  HOST_USERNAME = 'manager'.freeze
  HOST_PW = ''.freeze

  HOST_PROMPT = /\/[$%#>]/s
  LOGIN_PROMPT = /[Ll]ogin[: ]/
  PASSWORD_PROMPT = /[Pp]ass(?:word|phrase)[: ]/

  REGEX_CARDS = /\b\w+:.+/
  REGEX_SLOT_LINES = /\bunit[- ].+\|.+\b/ # If wants fan unit: /\b(?:fan|unit)[- ].+\b/
  REGEX_SHDSL_PORTS = /\blogport\W.*/ # /\logport-\w+\s(\|[\w\s\.:\?-]+){7}(.+)/
  REGEX_DSL_VALUES = /[\w|\W]\w.+\B\\\B/

  # Function <tt>create_ssh_session</tt> establishes ssh connection to jump server.
  # @return [Net::SSH] session
  def create_ssh_session
    Net::SSH.start(JUMPSRV, JUMPSRV_USER, password: JUMPSRV_PW, timeout: 20) # verbose: :info,
  end

  # Function <tt>disconnect</tt> closes the host session.
  # @return [boolean] value
  def close_ssh_session(session)
    session.close
    session = nil
    true
  end

  class Milegate
    attr_accessor :ssh_session

    def initialize(ssh_session)
      super()
      self.ssh_session = ssh_session
    end

    @telnet

    # Function <tt>connect</tt> establishes final host connection over ssh session.
    # @return [boolean] value
    def connect(host)
      sample = ''

      @telnet = Net::SSH::Telnet.new('Session' => ssh_session, 'Prompt' => LOGIN_PROMPT, 'Timeout' => 50)

      # sends telnet command
      @telnet.puts format('telnet %s', host)
      @telnet.waitfor('Match' => LOGIN_PROMPT) { |rcvdata| sample << rcvdata }

      # sends username
      @telnet.puts HOST_USERNAME
      @telnet.waitfor('Match' => PASSWORD_PROMPT) { |rcvdata| sample << rcvdata }

      # sends password and waits for cli prompt or login error phrase
      @telnet.puts HOST_PW
      @telnet.waitfor('Match' => HOST_PROMPT) { |rcvdata| sample << rcvdata }

      true
    end

    # Function <tt>disconnect</tt> closes the host session.
    # @return [boolean] value
    def disconnect
      @telnet.close
      true
    end

    # Function <tt>get_host_data</tt> executes low level commands over the connection
    # @return [array] value
    def get_low_level_data(cmd, regex, splitter_regex)
      sample = ''
      # sends cmd to host
      @telnet.puts(cmd) { |str| print str }

      # waits for cli prompt and stores returned data into sample variable
      @telnet.waitfor('Match' => HOST_PROMPT) { |rcvdata| sample << rcvdata }

      print "\n Return of low level command:\n #{sample}"

      sample.scan(regex)[0].split(splitter_regex)
    end

    # Function <tt>get_transceivers_detail</tt> gets transceivers detail
    # @return 1x6 [array] - port_1, Tx-Power_1, Rx-Power_1, port_2, Tx-Power_2, Rx-Power_2
    # ex.: ["1/25", "-4.2", "-13.0", "1/26", "-7.4", "-8.1"]
    def get_transceivers_detail
      cmd = 'sh hardware-status transceivers detail'
      regex = /((\w\/\w+)|-\d+\.\d+)/
      data_splitter = /\s+/

      get_low_level_data(cmd, regex, data_splitter)
    end

    # Function <tt>get_all_cards</tt> gets all the system cards and its operational status.
    # @return [array] value
    def get_all_cards
      result = []
      sample = ''
      cmd = 'ls / -e'

      #
      #     ID             | Name      | Main Mode      | Equip State | Alarm Sev | Prop Alarm Sev | User Label | Service Label | Description
      #     ---------------+-----------+----------------+-------------+-----------+----------------+------------+---------------+------------
      #     eoam           |           |                |             | Cleared   | Cleared        |            |               |
      #     fan            | FANU4     |                | Ok          | Cleared   | Warning        |            |               |
      #     multicast      |           |                |             | Cleared   | Cleared        |            |               |
      #     services       |           |                |             | Cleared   | Cleared        | unit-10    |               |
      #     tdmConnections |           |                |             | Cleared   | Cleared        |            |               |
      #     unit-1         | SUPC4 R1G | supm4_r2d01    | Ok          | Cleared   | Minor          |            |               |
      #     unit-2         | SUV11 R1J | suv11_r3e11_01 | Ok          | Cleared   | Cleared        |            |               |
      #     unit-3         | SUPC4 R1G | supm4_r2d01    | Ok          | Cleared   | Minor          |            |               |
      #     unit-4         | SUV11 R1J | suv11_r3e11_01 | Ok          | Cleared   | Cleared        |            |               |
      #     unit-5         | SUPC4 R1G | supm4_r2d01    | Ok          | Cleared   | Minor          |            |               |
      #     unit-6         | SUV11 R1J | suv11_r3e11_01 | Ok          | Cleared   | Cleared        |            |               |
      #     unit-7         | SUPC4 R1G | supm4_r2d01    | Ok          | Cleared   | Cleared        |            |               |
      #     unit-8         | SUV11 R1J | suv11_r3e11_01 | Ok          | Cleared   | Cleared        |            |               |
      #     unit-9         | SUPC4 R1G | supm4_r2d01    | Ok          | Cleared   | Minor          |            |               |
      #     unit-10        | SUV11 R1J | suv11_r3e11_01 | Ok          | Cleared   | Cleared        |            |               |
      #     unit-11        | COGE3 R1H | co3un_r2g01    | Ok          | Cleared   | Cleared        |            |               |
      #     unit-12        | IPSX3 R2B | ipsm2_r7d04_02 | Ok          | Cleared   | Cleared        |            |               |
      #     unit-13        | COGE3 R1H | co3un_r2g01    | Ok          | Cleared   | Cleared        |            |               |
      #     unit-14        | SUPC4 R1G | supm4_r2d01    | Ok          | Cleared   | Minor          |            |               |
      #     unit-15        | SUPC4 R1G | supm4_r2d01    | Ok          | Cleared   | Minor          |            |               |
      #     unit-16        | SUPC4 R1G | supm4_r2d01    | Ok          | Cleared   | Minor          |            |               |
      #     unit-17        | SUPC4 R1G | supm4_r2d01    | Ok          | Cleared   | Minor          |            |               |
      #     unit-18        | SUPC4 R1G | supm4_r2d01    | Ok          | Cleared   | Minor          |            |               |
      #     unit-19        | SUPC4 R1G | supm4_r2d01    | Ok          | Cleared   | Cleared        |            |               |
      #     unit-20        | SUPC4 R1G | supm4_r2d01    | Ok          | Cleared   | Cleared        |            |               |
      #     unit-21        | SUSE1 R1D | suse1_r5b02_02 | Ok          | Cleared   | Major          |            |               |
      #     />
      # =end
      @telnet.puts(cmd) { |str| print str }
      @telnet.waitfor('Match' => HOST_PROMPT) { |rcvdata| sample << rcvdata }

      sample.scan(REGEX_SLOT_LINES).each do |line|
        values = line.split(/\|/).map { |e| e || '' } # Replaces nil values of array

        next if values[3].to_s =~ /Empty/ # If slot is not empty
        result << {
          id: values[0].strip!,
          name: values[1].strip!,
          main_mode: values[2].strip!,
          state: values[3].strip!,
          alarm: values[4].strip!,
          prop_alarm: values[5].strip!
        }
      end
      result
    end

    # Function <tt>get_card_alarms</tt> gets all not running system.
    # @return [array] value
    def get_card_alarms
      result = []
      alarmed_cards = get_all_cards.reject { |slot| slot[:state].match(/Ok/) }

      alarmed_cards.each do |card|
        if card[:name] =~ /COGE/
          prior = 'Minor'
          msg = 'Cartao nao comissionado ou desativado presente no slot'

        else
          prior = 'Critical'
          msg = 'Cartao com falha inoperante'

        end

        result << ['CARD', card[:id], "#{card[:name]} #{card[:state]}", prior, msg]
      end

      result
    end

    # Function <tt>get_cards_by_name(name)</tt> gets system cards by name.
    # Depends on the function <tt>get_slots_all</tt>.
    # @return [array] value
    def get_cards_by_name(name)
      get_all_cards.select { |slot| slot[:name].match(name) }
    end

    # Function <tt>get_shdsl_ports_all</tt> gets all shdsl ports and its labels from STIM cards.
    # @return [array] value
    def get_shdsl_ports_all(slot)
      result = []
      sample = ''
      cmd = "ls /#{slot[:id]}/logports -e"

       #
       #       ID         | Name       | Main Mode         | Equip State | Alarm Sev | Prop Alarm Sev | User Label | Service Label | Description
       #       -----------+------------+-------------------+-------------+-----------+----------------+------------+---------------+------------
       #       logport-1  | SHDSL Span | ports:1,2,3,4     |             | Cleared   | Cleared        |            |               |
       #       logport-5  | SHDSL Span | ports:5,6,7,8     |             | Cleared   | Cleared        |            |               |
       #       logport-9  | SHDSL Span | ports:9,10,11,12  |             | Cleared   | Cleared        |            |               |
       #       logport-13 | SHDSL Span | ports:13,14,15,16 |             | Cleared   | Cleared        |            |               |
       #       logport-17 | SHDSL Span | ports:17,18,19,20 |             | Cleared   | Cleared        |            |               |
       #       logport-21 | SHDSL Span | ports:21,22,23,24 |             | Cleared   | Cleared        |            |               |
       #       logport-25 | SHDSL Span | ports:25,26,27,28 |             | Cleared   | Cleared        |            |               |
       #       logport-29 | SHDSL Span | ports:29,30,31,32 |             | Cleared   | Cleared        |            |               |
       #       /unit-21/logports>
      @telnet.puts(cmd) { |str| print str }
      @telnet.waitfor('Match' => HOST_PROMPT) { |rcvdata| sample << rcvdata }

      sample.scan(REGEX_SHDSL_PORTS).each do |row|
        values = row.split(/\|/).map { |e| e || '' } # Replaces nil values of array
        result << {
          id: values[0].strip!,
          main_mode: values[2].strip!,
          alarm: values[4].strip!,
          user_label: values[6].strip!,
          service_label: values[7].strip!,
          description: values[8].strip!
        }
      end
      result
    end

    # Function <tt>get_shdsl_params</tt> gets shdsl line parameters.
    # @return [array] value
    def get_shdsl_params(slot, port)
      result = []
      sample = ''

      cmd = "get /#{slot[:id]}/port-#{port}/status/LineOperationState"

      #       /unit-21> get port-1/status/LineOperationState
      #                                                                          \ # LineOperationalStatus
      #       WaitForG.Handshaking                                               \ # State
      #       /unit-21>
      @telnet.puts(cmd) { |str| print str }
      @telnet.waitfor('Match' => HOST_PROMPT) { |rcvdata| sample << rcvdata }

      sample.scan(REGEX_DSL_VALUES).each do |value|
        # puts value.to_s.scan(/\w+/)[0]
        result << value.scan(/[\w|\.]+/)[0]
      end
      result
    end
  end
end
