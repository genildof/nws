# Make sure HOME is set, regardless of OS, so that File.expand_path works
# as expected with tilde characters.

# ENV['HOME'] ||= ENV['HOMEPATH'] ? "#{ENV['HOMEDRIVE']}#{ENV['HOMEPATH']}" : Dir.pwd

require 'net/ssh/telnet'

module Datacom

  JUMPSRV_NMC = '10.200.1.34'
  JUMPSRV_NMC_USER = 'nmc'
  JUMPSRV_NMC_PW = 'nmcgvt25'

  JUMPSRV = '10.200.1.29'
  JUMPSRV_USERNAME = 'sp3510717'
  JUMPSRV_PW = 'Lima.1010'

  #RADIUS_USERNAME = 'g0010717'
  #RADIUS_PW = 'Lima.10'

  RADIUS_USERNAME = 'g0001959'
  RADIUS_PW = 'Vivo15'

  PROMPT = /\w+[$%#>]/s
  LOGIN_PROMPT = /[Ll]ogin[: ]/
  PASSWORD_PROMPT = /[Pp]ass(?:word|phrase)[: ]/

  # Function <tt>create_ssh_session</tt> establishes ssh connection to jump server.
  # @return [Net::SSH] session
  def create_ssh_session
    return Net::SSH.start(JUMPSRV_NMC, JUMPSRV_NMC_USER, password: JUMPSRV_NMC_PW, timeout: 40) # verbose: :info,
  end

  # Function <tt>disconnect</tt> closes the host session.
  # @return [boolean] value
  def close_ssh_session(session)
    session.close
    session = nil
    true
  end

  class DMSW

    attr_accessor :ssh_session

    @telnet

    def initialize(ssh_session)
      super()
      self.ssh_session = ssh_session
    end

    # Function <tt>connect</tt> establishes final host connection over ssh session.
    # @return [boolean] value
    def connect(host, retrying)
      sample = ''

      @telnet = Net::SSH::Telnet.new('Session' => ssh_session, 'Prompt' => LOGIN_PROMPT, 'Timeout' => 60)

      # sends telnet command
      @telnet.puts format('telnet %s', host[:ip])
      @telnet.waitfor('Match' => LOGIN_PROMPT) { |rcvdata| sample << rcvdata }

      case retrying
        when false
          @telnet.puts RADIUS_USERNAME
          @telnet.waitfor('Match' => PASSWORD_PROMPT) { |rcvdata| sample << rcvdata }
          @telnet.puts RADIUS_PW
          @telnet.waitfor('Match' => /(?:\w+[$%#>]|Login incorrect)/) { |rcvdata| sample << rcvdata }

        when true
          @telnet.puts 'admin'
          @telnet.waitfor('Match' => PASSWORD_PROMPT) { |rcvdata| sample << rcvdata }
          @telnet.puts 'admin'
          @telnet.waitfor('Match' => /(?:\w+[$%#>]|Login incorrect)/) { |rcvdata| sample << rcvdata }
      end

      sample.match(PROMPT) ? true : false
    end

    # Function <tt>disconnect</tt> closes the host session.
    # @return [boolean] value
    def disconnect
      @telnet.close
      true
    end

    # Function <tt>get_host_data</tt> executes low level commands over the connection
    # @return [array]
    def get_low_level_data(cmd, regex, splitter_regex)
      sample = ''
      # sends cmd to host
      @telnet.puts(cmd) { |str| print str }

      # waits for cli prompt and stores returned data into sample variable
      @telnet.waitfor('Match' => PROMPT) { |rcvdata| sample << rcvdata }

      #print "\n Return of low level command:\n #{sample}"
      (sample.scan(regex)[0].nil? ? nil : sample.scan(regex)[0].split(splitter_regex))
    end

    # Function <tt>get_transceivers_detail</tt> gets transceivers detail
    # @return 1x6 [array] - port_1, Tx-Power_1, Rx-Power_1, port_2, Tx-Power_2, Rx-Power_2
    # ex.: ["1/25", "-4.2", "-13.0", "1/26", "-7.4", "-8.1"]
    def get_transceivers_detail
      cmd = 'sh hardware-status transceivers detail'
      regex = /((\w\/\w+)|-\d+\.\d+)/
      data_splitter = /\s+/

      get_low_level_data(cmd, regex, data_splitter)

      # sample text
      #       D2BRE36BBR01#sh hardware-status transceivers detail
      #       Information of port 1/25
      #       Vendor information:
      #                  Vendor Name:               OEM
      #       Manufacturer:              OEM
      #       Part Number:               WDM-0210BD
      #       Serial Number:             6C1501V450
      #       Media:                     Single Mode (SM)
      #       Ethernet Standard:         [Not available]
      #       Connector:                 LC
      #       Digital Diagnostic:
      #                   Temperature:               30 C
      #       Voltage 3.3V:              3.3V
      #       Current:                   31.6mA
      #       Tx-Power:                  -4.2dBm
      #       Rx-Power:                  -13.0dBm
      #
      #       Information of port 1/26
      #       Vendor information:
      #                  Vendor Name:               OEM
      #       Manufacturer:              OEM
      #       Part Number:               WDM-0210-AD-C
      #       Serial Number:             1404L00759
      #       Media:                     Single Mode (SM)
      #       Ethernet Standard:         [Not available]
      #       Connector:                 LC
      #       Digital Diagnostic:
      #                   Temperature:               31 C
      #       Voltage 3.3V:              3.3V
      #       Current:                   30.0mA
      #       Tx-Power:                  -7.4dBm
      #       Rx-Power:                  -8.1dBm
      #
      #       D2BRE36BBR01#
    end

    # Function <tt>get_eaps_status</tt> gets eaps redundancy protocol status.
    # @return 1x8 [array] - ID, Domain, State, Mode, Port, Port, VLAN, Groups/VLANs
    # ex.: ["0", "gvt", "Complete", "M", "1/25", "1/26", "4094", "1/4093"]
    def get_eaps_status
      cmd = 'show eaps'
      regex = /\b\d\s.+/
      data_splitter = /\s+/

      result = get_low_level_data(cmd, regex, data_splitter)
      result.map { |e| e || '' } if !result.nil? # replaces nil values

      result.nil? ? ["", "", "no eaps configured", "", "", "", "", ""] : result

      # sample text
      #       D2SPO10CDR01#sh eaps
      #       EAPS information:
      #
      #                Mode: M - Master
      #       T - Transit
      #
      #       Pri     Sec    Ctrl   Protected
      #       ID       Domain           State       Mode   Port    Port   VLAN  Groups/VLANs
      #       --  ---------------  ---------------  ----  ------  ------  ----  ------------
      #       0   gvt              Links-Up          T     1/25    1/26   4094    1/4093
      #
      #       D2SPO10CDR01#
    end
  end
end
