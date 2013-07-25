#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

$LOAD_PATH.push File.dirname($0)

require "rubygems"
require "serialport"
require "remocon_analyzer"
require 'optparse'

def usage()
  puts "Usage: #{File.basename($0)} [OPTION] USB_TTY"
  puts ""
  puts "Options:"
  puts "  -b, --baud_rate=RATE specify the baud rate of serial communication"
  puts "                       default is 19200"
  puts "  -v, --verbose        output verbose format"
  puts "  -d, --debug          debug mode"
  puts "  -h, --help           display this help and exit"
  exit 1
end

debug=false
verbose=false
speed=19200
OptionParser.new {|opt|
  opt.on("--baud_rate=RATE") {|v|
    speed = v.to_i
  }
  opt.on("--debug") {
    debug=true
  }
  opt.on("--verbose") {
    verbose=true
  }
  opt.on("--help") {
    usage
  }
  opt.parse!(ARGV)
}

usage if ARGV.empty?
PORT=ARGV.shift

sp = SerialPort.new(PORT, speed, 8, 1, 0) # 8bit, stopbit 1, parity none

# receive
Thread.new do
  begin
    loop do
      line = sp.gets
      if line==nil
        puts "Device was detattched. [#{PORT}]"
        exit 1
      end
      line = line.scan(/[[:print:]]/).join
      if line.index("received,")==0
        r=RemoconAnalyzer.parse(line)
        puts r.dump
        puts r.verbose if verbose
        puts line if debug
      elsif line.index("echo,")==0
        puts line if debug
      else
        puts line
      end
    end
  rescue =>ex
    Thread.main.raise ex
  end
end

# send
loop do
  str = STDIN.gets
  data = RemoconAnalyzer.make_send_data(str)
  next if data.nil?
  (data+"\r\n").each_char {|s| sp.write s} # 1文字づつ転送する（バッファがあふれるので）
end
sp.close
