@echo off
C:\dev\jruby-1.7.16\bin\jruby.exe --2.0 -e $stdout.sync=true;$stderr.sync=true;load($0=ARGV.shift) C:/dev/RubymineProjects/nwslib/app/infrastructure_alarms.rb
