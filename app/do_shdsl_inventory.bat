@echo off
%jruby_home%\bin\jruby.exe --2.0 -e $stdout.sync=true;$stderr.sync=true;load($0=ARGV.shift) C:/dev/RubymineProjects/nwslib/app/shdsl_inventory.rb
