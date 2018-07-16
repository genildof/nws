require 'net/ssh/telnet'

module Datacom

  class DMSW

    # Session's constants for Zhone MXK

    JUMPSRV_NMC = '10.200.1.34'
    JUMPSRV_NMC_USER = 'nmc'
    JUMPSRV_NMC_PW = 'nmcgvt25'

    JUMPSRV = '10.200.1.29'
    JUMPSRV_USERNAME = 'sp3510717'
    JUMPSRV_PW = 'Lima.1010'

    RADIUS_USERNAME = 'g0010717'
    RADIUS_PW = 'Lima.10'

    PROMPT = /\/[$%#>]/s
    LOGIN_PROMPT = /[Ll]ogin[: ]/
    PASSWORD_PROMPT = /[Pp]ass(?:word|phrase)[: ]/

    # Detection patterns's constants for Zhone MXK
    REGEX_ALARM = /\bsystem.+/
    REGEX_INTERFACE = /\b(?:Primary|Secondary).+\b/
    REGEX_CARDS = /\b\w+:.+/

    @channel
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
        @channel = Net::SSH.start(JUMPSRV_NMC, JUMPSRV_NMC_USER, :password => JUMPSRV_NMC_PW)
      rescue
        raise "Failed connecting proxy server at %s\n" % [JUMPSRV_NMC]
      end

      begin
        @telnet = Net::SSH::Telnet.new("Session" => @channel,
                                       "Prompt" => LOGIN_PROMPT,
                                       'Timeout' => 10,
                                       'Host' => self.ip_address)
        @telnet.login('Name' => USERNAME, 'Password' => USER_PW,
                      'LoginPrompt' => LOGIN_PROMPT, 'PasswordPrompt' => PASSWORD_PROMPT) # { |str| print str }
        #rescue
        # raise "Failed connecting to end host %s from gateway %s \n" % [self.ip_address, JUMPSRV_NMC]
      end

      true
    end

    # Function <tt>disconnect</tt> closes the session.
    # @return [boolean] value
    def disconnect
      @telnet.close
      @channel.close
      true
    end

    # Function <tt>get_eaps_status</tt> gets eaps redundancy protocol status.
    # @returns default 1x8 [array] - ID, Domain, State, Mode, Port, Port, VLAN, Groups/VLANs, ex.: [0, 'gvt', 'Links-Up', T, 1/25, 1/26, 4094, 1/4093]
    def get_eaps_status

      result = Array.new
      sample = ''
      cmd = 'show eaps'
      row_regex = /\b\d\s.+/
      splitter_regex = /\s+/

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

      # sends cmd to host

      @telnet.puts(cmd) {|str| print str}

      # waits for cli prompt and stores returned data into sample variable
      @telnet.waitfor('Match' => PROMPT) {|rcvdata| sample << rcvdata}

      sample.scan(row_regex)[0].split(splitter_regex)
    end

  end # DMSW Class

end # Module