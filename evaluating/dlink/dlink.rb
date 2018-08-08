# To change this template, choose Tools | Templates
# and open the template in the editor.

require 'net/telnet'

tn = Net::Telnet::new(
  "Timeout" => 2,
  "Prompt"  => /[$%#>:] \z/n,
	'Host' => '192.168.100.1'
)	{ |str| print str }


begin
  tn.login("admin", "genildof")	{ |str| print str }
  puts "\nOk !\n"
  tn.cmd('?') { |str| print str }
  tn.
    rescue TimeoutError
  puts "\nLogin failed !\n"
  # fail "Login failed !\n"
end

