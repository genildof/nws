require 'net/ssh/telnet'

module Keymile

  class Milegate

    JUMPSRV = '200.204.4.1'
    JUMPSRV_USER = 'r101521'
    JUMPSRV_PW = 'guerr@01'

    RADIUS_USERNAME = 'manager'
    RADIUS_PW = ''

    HOST_PROMPT = /\w+[$%#>]/s
    LOGIN_PROMPT = /[Ll]ogin[: ]/
    PASSWORD_PROMPT = /[Pp]ass(?:word|phrase)[: ]/

    # Detection patterns's constants for Zhone MXK
    REGEX_ALARM = /\bsystem.+/
    REGEX_INTERFACE = /\b(?:Primary|Secondary).+\b/
    REGEX_CARDS = /\b\w+:.+/

    @telnet
    @session

    # Function <tt>connect</tt> establishes final host connection over ssh session.
    # @return [boolean] value
    def connect(host)
      sample = ''

      @session = Net::SSH.start(JUMPSRV, JUMPSRV_USER, :password => JUMPSRV_PW, :verbose => :debug, :timeout => 30)

      print "\nTrying telnet to end host from proxy server"
      @telnet = Net::SSH::Telnet.new("Session" => @session, "Prompt" => LOGIN_PROMPT, 'Timeout' => 30)

      # sends telnet command
      @telnet.puts "telnet %s" % [host]
      @telnet.waitfor('Match' => LOGIN_PROMPT) {|rcvdata| sample << rcvdata}

      print "\nReturn of command: #{sample}"

      # sends username
      @telnet.puts RADIUS_USERNAME
      @telnet.waitfor('Match' => PASSWORD_PROMPT) {|rcvdata| sample << rcvdata}

      # sends password and waits for cli prompt or login error phrase
      print "\nTrying logon with radius password... #{host}"

      @telnet.puts RADIUS_PW
      @telnet.waitfor('Match' => /(?:\w+[$%#>]|Login incorrect)/) {|rcvdata| sample << rcvdata}

      print "\nReturn of command: #{sample}"

      # Retry login with default user & password
      if sample.match(/\b(Login incorrect)/)
        print "\nFailed. Retrying with default password... #{host}"
        # sends username
        @telnet.puts 'admin'
        @telnet.waitfor('Match' => PASSWORD_PROMPT) {|rcvdata| sample << rcvdata}

        # sends password and waits for cli prompt
        @telnet.puts 'admin'
        @telnet.waitfor('Match' => HOST_PROMPT) {|rcvdata| sample << rcvdata}
        if sample.match(HOST_PROMPT)
          print "\n#{host} - Default password accepted."
        else
          print "\n#{host} - Second attempt failed."
        end
      else
        print "\n#{host} Radius password accepted."
      end

      true
    end

    # Function <tt>disconnect</tt> closes the host session.
    # @return [boolean] value
    def disconnect()
      @telnet.close
      @session.close
      true
    end

    # Function <tt>get_host_data</tt> executes low level commands over the connection
    # @return [array]
    def get_low_level_data cmd, regex, splitter_regex
      sample = ''
      # sends cmd to host
      @telnet.puts(cmd) {|str| print str}

      # waits for cli prompt and stores returned data into sample variable
      @telnet.waitfor('Match' => HOST_PROMPT) {|rcvdata| sample << rcvdata}

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

      #sample text
=begin
      D2BRE36BBR01#sh hardware-status transceivers detail
      Information of port 1/25
      Vendor information:
                 Vendor Name:               OEM
      Manufacturer:              OEM
      Part Number:               WDM-0210BD
      Serial Number:             6C1501V450
      Media:                     Single Mode (SM)
      Ethernet Standard:         [Not available]
      Connector:                 LC
      Digital Diagnostic:
                  Temperature:               30 C
      Voltage 3.3V:              3.3V
      Current:                   31.6mA
      Tx-Power:                  -4.2dBm
      Rx-Power:                  -13.0dBm

      Information of port 1/26
      Vendor information:
                 Vendor Name:               OEM
      Manufacturer:              OEM
      Part Number:               WDM-0210-AD-C
      Serial Number:             1404L00759
      Media:                     Single Mode (SM)
      Ethernet Standard:         [Not available]
      Connector:                 LC
      Digital Diagnostic:
                  Temperature:               31 C
      Voltage 3.3V:              3.3V
      Current:                   30.0mA
      Tx-Power:                  -7.4dBm
      Rx-Power:                  -8.1dBm

      D2BRE36BBR01#
=end

    end

    # Function <tt>get_eaps_status</tt> gets eaps redundancy protocol status.
    # @return 1x8 [array] - ID, Domain, State, Mode, Port, Port, VLAN, Groups/VLANs
    # ex.: ["0", "gvt", "Complete", "M", "1/25", "1/26", "4094", "1/4093"]
    def get_eaps_status

      cmd = 'show eaps'
      regex = /\b\d\s.+/
      data_splitter = /\s+/

      self.get_low_level_data(cmd, regex, data_splitter)

      #sample text
=begin
      D2SPO10CDR01#sh eaps
      EAPS information:

               Mode: M - Master
      T - Transit

      Pri     Sec    Ctrl   Protected
      ID       Domain           State       Mode   Port    Port   VLAN  Groups/VLANs
      --  ---------------  ---------------  ----  ------  ------  ----  ------------
      0   gvt              Links-Up          T     1/25    1/26   4094    1/4093

      D2SPO10CDR01#
=end
    end

  end

end
