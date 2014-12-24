# To change this template, choose Tools | Templates
# and open the template in the editor.
#  'login_prompt' => /[Ll]ogin[: ]*\z/n,
#  'password_prompt' => /[Pp]assword[: ]*\z/n,
#  "Timeout" => 2,
#	'Host' => '10.161.64.98'

require 'net/telnet'

tn = Net::Telnet::new(
  'Prompt' => /.[$%#>:]/n,
  'Timeout' => 5,
	'Host' => '10.161.64.98'
)	{ |str| print str }

begin
  tn.login('genildos_cpe', 'gen819ildo')	{ |str| print str }
  puts '\nok !\n'
  tn.cmd('qdn 6730256377') { |str| print str }
  tn.rescue TimeoutError
  puts '\nLogin failed !\n'
  # fail "Login failed !\n"
end


