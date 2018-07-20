# Make sure HOME is set, regardless of OS, so that File.expand_path works
# as expected with tilde characters.

#ENV['HOME'] ||= ENV['HOMEPATH'] ? "#{ENV['HOMEDRIVE']}#{ENV['HOMEPATH']}" : Dir.pwd

require 'net/ssh/telnet'
require 'logger'

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

    PROMPT = /\w+[$%#>]/s
    LOGIN_PROMPT = /[Ll]ogin[: ]/
    PASSWORD_PROMPT = /[Pp]ass(?:word|phrase)[: ]/

    # Detection patterns's constants for Zhone MXK
    REGEX_ALARM = /\bsystem.+/
    REGEX_INTERFACE = /\b(?:Primary|Secondary).+\b/
    REGEX_CARDS = /\b\w+:.+/

    @logger = Logger.new(STDOUT)

    @telnet
    @session

    def initialize()
      super()
    end

    # Function <tt>connect</tt> establishes final host connection over ssh session.
    # @return [boolean] value
    def connect(host)

      false
      sample = ''

      @logger.info "Creating ssh main session... #{host}" if $DEBUG
      @session = Net::SSH.start(JUMPSRV_NMC, JUMPSRV_NMC_USER, :password => JUMPSRV_NMC_PW)

      @logger.info "Trying telnet to end host from proxy server" if $DEBUG
      @telnet = Net::SSH::Telnet.new("Session" => @session, "Prompt" => LOGIN_PROMPT, 'Timeout' => 30)

      # sends telnet command
      @telnet.puts "telnet %s" % [host]
      @telnet.waitfor('Match' => LOGIN_PROMPT) {|rcvdata| sample << rcvdata}

      @logger.info "Return of command: #{sample}" if $DEBUG

      # sends username
      @telnet.puts RADIUS_USERNAME
      @telnet.waitfor('Match' => PASSWORD_PROMPT) {|rcvdata| sample << rcvdata}

      # sends password and waits for cli prompt or login error phrase
      @logger.info "Trying logon with radius password... #{host}" if $DEBUG

      @telnet.puts RADIUS_PW
      @telnet.waitfor('Match' => /(?:\w+[$%#>]|Login incorrect)/) {|rcvdata| sample << rcvdata}

      @logger.info "Return of command: #{sample}" if $DEBUG

      # Retry login with default user & password
      if sample.match(/\b(Login incorrect)/)
        @logger.info "Failed. Retrying with default password... #{host}" if $DEBUG
        # sends username
        @telnet.puts 'admin'
        @telnet.waitfor('Match' => PASSWORD_PROMPT) {|rcvdata| sample << rcvdata}

        # sends password and waits for cli prompt
        @telnet.puts 'admin'
        @telnet.waitfor('Match' => PROMPT) {|rcvdata| sample << rcvdata}
        if sample.match(PROMPT)
          @logger.info "#{host} - Default password accepted." if $DEBUG
        else
          @logger.info "#{host} - Second attempt failed." if $DEBUG
        end
      else
        @logger.info "#{host} Radius password accepted." if $DEBUG
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

    # Function <tt>get_eaps_status</tt> gets eaps redundancy protocol status.
    # @returns default 1x8 [array] - ID, Domain, State, Mode, Port, Port, VLAN, Groups/VLANs, ex.: ["0", "gvt", "Complete", "M", "1/25", "1/26", "4094", "1/4093"]
    def get_eaps_status

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

      @logger.info "Return of command: #{sample}" if $DEBUG

      sample.scan(row_regex)[0].split(splitter_regex)
    end

  end

end