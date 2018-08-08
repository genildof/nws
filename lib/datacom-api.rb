# Make sure HOME is set, regardless of OS, so that File.expand_path works
# as expected with tilde characters.

# ENV['HOME'] ||= ENV['HOMEPATH'] ? "#{ENV['HOMEDRIVE']}#{ENV['HOMEPATH']}" : Dir.pwd

require 'net/ssh/telnet'

module Datacom
  class DMSW
    # Session's constants for Zhone MXK

    JUMPSRV_NMC = '10.200.1.34'.freeze
    JUMPSRV_NMC_USER = 'nmc'.freeze
    JUMPSRV_NMC_PW = 'nmcgvt25'.freeze

    JUMPSRV = '10.200.1.29'.freeze
    JUMPSRV_USERNAME = 'sp3510717'.freeze
    JUMPSRV_PW = 'Lima.1010'.freeze

    #RADIUS_USERNAME = 'g0010717'.freeze
    #RADIUS_PW = 'Lima.10'.freeze

    RADIUS_USERNAME = 'g0001959'
    RADIUS_PW = 'Vivo15'

    PROMPT = /\w+[$%#>]/s
    LOGIN_PROMPT = /[Ll]ogin[: ]/
    PASSWORD_PROMPT = /[Pp]ass(?:word|phrase)[: ]/

    # Detection patterns's constants for Zhone MXK
    REGEX_ALARM = /\bsystem.+/
    REGEX_INTERFACE = /\b(?:Primary|Secondary).+\b/
    REGEX_CARDS = /\b\w+:.+/

    # @logger = Logger.new(STDOUT)

    @telnet
    @session
    @login_type

    def initialize
      super()
    end

    # Function <tt>get_login_type</tt> returns login_type
    # @return [string] login_type
    def get_login_type
      @login_type
    end

    # Function <tt>connect</tt> establishes final host connection over ssh session.
    # @return [boolean] value
    def connect(host)
      sample = ''
      @login_type = nil

      print "Creating ssh main session... #{host}"
      @session = Net::SSH.start(JUMPSRV_NMC, JUMPSRV_NMC_USER, password: JUMPSRV_NMC_PW)

      print "\nTrying telnet to end host from proxy server"
      @telnet = Net::SSH::Telnet.new('Session' => @session, 'Prompt' => LOGIN_PROMPT, 'Timeout' => 30)

      # sends telnet command
      @telnet.puts format('telnet %s', host)
      @telnet.waitfor('Match' => LOGIN_PROMPT) { |rcvdata| sample << rcvdata }

      # print "\nReturn of command: #{sample}"

      # sends username
      @telnet.puts RADIUS_USERNAME
      @telnet.waitfor('Match' => PASSWORD_PROMPT) { |rcvdata| sample << rcvdata }

      # sends password and waits for cli prompt or login error phrase
      print "\nTrying logon with radius password... #{host}"

      @telnet.puts RADIUS_PW
      @telnet.waitfor('Match' => /(?:\w+[$%#>]|Login incorrect)/) { |rcvdata| sample << rcvdata }

      # print "\nReturn of command: #{sample}"

      # Retry login with default user & password
      if sample =~ /\b(Login incorrect)/
        print "\nFailed. Retrying with default password... #{host}"
        # sends username
        @telnet.puts 'admin'
        @telnet.waitfor('Match' => PASSWORD_PROMPT) { |rcvdata| sample << rcvdata }

        # sends password and waits for cli prompt
        @telnet.puts 'admin'
        @telnet.waitfor('Match' => PROMPT) { |rcvdata| sample << rcvdata }
        if sample.match(PROMPT)
          print "\n#{host} - Default password accepted."
          @login_type = 'vendor'
        else
          print "\n#{host} - Second attempt failed."
        end
      else
        print "\n#{host} Radius password accepted."
        @login_type = 'radius'
      end

      true
    end

    # Function <tt>disconnect</tt> closes the host session.
    # @return [boolean] value
    def disconnect
      @telnet.close
      @session.close
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

      get_low_level_data(cmd, regex, data_splitter)

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
