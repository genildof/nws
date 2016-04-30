message = <<-MSG

>> Error: SNE-A20-99  RIN 134 - 10.209.33.133: #<NoMethodError: undefined method `strip' for nil:NilClass>

ID        | Name       | Main Mode | Equip State | Alarm Sev | Prop Alarm Sev | User Label                     | Service Label                  | Description
----------+------------+-----------+-------------+-----------+----------------+--------------------------------+--------------------------------+------------
logport-1 | SHDSL Span | port-1    |             | Major     | Major          | Cliente: DREUX & TIESE         | Designador: SNE-3010173WL-032
 |
logport-2 | SHDSL Span | port-2    |             | Cleared   | Cleared        | Cliente:BEKHOFF AUTOMA??O IN | Designador:SNE-301B7R7NC-032   |
logport-3 | SHDSL Span | port-3    |             | Cleared   | Cleared        | Cliente:ESCRITORIO MATTOS AS   | Designador:SNE-301KGI0HX-032   |
logport-8 | SHDSL Span | port-8    |             | Cleared   | Cleared        | Cliente:SOLIDSOFT SISTEMAS     | Designador:SNE-30VLYUER-032    |
/>

>> Error: SNE-A21-0  RIN 110 - 10.209.33.109: #<NoMethodError: undefined method `strip' for nil:NilClass>

ID        | Name       | Main Mode | Equip State | Alarm Sev | Prop Alarm Sev | User Label                   | Service Label                 | Description
----------+------------+-----------+-------------+-----------+----------------+------------------------------+-------------------------------+-----------------
logport-1 | SHDSL Span | port-1    |             | Major     | Cleared        | Cliente: SOUZA LEITE         | Designador: SNE-301KH73OZ-032 |
logport-2 | SHDSL Span | port-2    |             | Cleared   | Cleared        | Cliente: ELOS CONEXOES       | Designador: SNE-30ZG7D1B      |
logport-3 | SHDSL Span | port-3    |             | Cleared   | Warning        | Cliente: ELOS CONEXOES       |
Designador: SNE-30ZG7M5L-032 |
logport-4 | SHDSL Span | port-4    |             | Cleared   | Cleared        | Cliente: LPS BRASIL          | Designador:SNE-3017UKD59-032  |
logport-5 | SHDSL Span | port-5    |             | Cleared   | Cleared        | Cliente:ATLANTICA RADIADORES | Designador:SNE-3018ZVUGN-32   |
logport-6 | SHDSL Span | port-6    |             | Cleared   | Cleared        | Cliente:LPS BRASIL - CONSULT | Designador:SNE-301BR5XKW-032  |
logport-7 | SHDSL Span | port-7    |             | Cleared   | Cleared        | OPVS CONSULT                 | SNE-301JQYX40-032             | PAR: 1351 / 1352
logport-8 | SHDSL Span | port-8    |             | Cleared   | Cleared        | CLIENTE: SIENA ACESSORIOS    | WO: SNE301JRKYGZ-032          | PAR: 1353 / 1354
/>

MSG

# message.scan(/^logport.*$/m).each { |line| print "#{line}\n" }
#=> "From: person@example.com\nDate: 01-01-2011\nTo: friend@example.com\nSubject: This is the subject line"


require_relative '/../lib/cricket/service'
require_relative '/../lib/zhone/zhone-api'

hosts = Service::Cricket.new.get_dslam_list('SPO').select { |dslam| dslam.model.match(/Zhone/) }

hosts.each { |host|
  target = "#{host.dms_id}\tRIN #{host.rin}\t\tat #{host.ip}"

  begin
    dslam = Zhone::MXK.new(host.ip)
    dslam.connect

    print "\n#{target}"
    dslam.get_card_alarms.each { |card|
      print "\n\t\tAlarm >> #{card[0]} - #{card[1]}"
    }

    dslam.disconnect
  rescue => err
    puts "#{err.class} - #{err}"
  end

}
