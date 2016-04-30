


require 'net/telnet'

module Tellabs

  class Milegate

    # Equipment constants for use on CLI Release R2A00, Build 2011-02-07
    USERNAME = 'G0001959'
    USER_PW = 'Mara5128'
    PROMPT = /\/[$%#>]/s
    LOGIN_PROMPT = /[Ll]ogin as[: ]/
    PASSWORD_PROMPT = /[Pp]ass(?:word|phrase)[: ]/

    REGEX_SLOT_LINES = /\b(?:fan|unit)[- ].+\b/
    REGEX_SHDSL_PORTS = /\blogport-.+/
    REGEX_DSL_WITH_CAPTIONS = /\b\s\w{1,3}\W+\w+/
    REGEX_DSL_VALUES = /\b\s\w{1,4}/

    @telnet
    attr_accessor :ip_address

    def initialize(ip_address)
      super()
      self.ip_address = ip_address
    end

    # Function <tt>connect</tt> establishes connection and authentication to Milegate equipment.
    # @return [boolean] value
    def connect
      begin
        @telnet = Net::Telnet::new(
            'Prompt'  => PROMPT,
            'Timeout' => 15,
            'Host' => self.ip_address
        )	# { |str| print str }

        @telnet.login('Name' => USERNAME, 'Password' => USER_PW,
                      'LoginPrompt' => LOGIN_PROMPT, 'PasswordPrompt' => PASSWORD_PROMPT)	# { |str| print str }
        true
      rescue => err
        print "#{err.class} #{err}"
      end
    end

    def disconnect
      @telnet.close
      true
    end
  end
end


=begin
t7300-SW-SPSOC_O1A36# show interface transceiver

TX          RX          Supply      Temp        Bias
Power       Power       Voltage                 Current
Port      (dBm)       (dBm)       (V)         (C)         (mA)
-----     ---------   ---------   ---------   ---------   ---------
Xg1/2/1   2.71        -14.96      3.336       45          82592
Xg1/2/2   1.61        -8.76       3.392       45          82208
Gi1/2/3   -5.60       -5.34       3.359       30          2662
Gi1/2/4   -5.43       -36.99      3.355       38          3119
Gi1/2/5   -5.58       -6.31       3.363       36          2708
Gi1/2/6   -5.59       -5.80       3.366       35          2784
Gi1/2/13  -5.51       -33.01      3.346       43          3007
Gi1/2/14  -5.54       -5.38       3.341       35          2999
Gi1/2/15  -5.54       -99.00      3.359       35          2953
Gi1/2/16  -5.26       -25.85      3.327       41          2256
Gi1/2/25  -99.00      -99.00      3.300       25          0
Gi1/2/26  -99.00      -99.00      3.300       25          0

Serial0 up, 8 data bits, no parity, 38400 baud

t7300-SW-SPSOC_O1A36#
=end