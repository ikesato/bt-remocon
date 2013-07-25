# -*- coding: utf-8 -*-

require "sony_format"
require "nec_format"
require "jvc_format"
require "daikin_format"
require "raw_format"

class RemoconAnalyzer
  UNIT = 5.33333 * 0.001 # [ms]

  def self.parse(raw_str)
    ra = RemoconAnalyzer.new
    ra._parse(raw_str)
    ra
  end

  def _parse(raw_str)
    ary=raw_str.split(",")
    raise "parse error. first data should 'received'" if ary.shift != "received"
    ary.map! {|a|
      if a[0] != 'H' && a[0] != 'L'
        raise "parse error. need 'H' or 'L'"
      end
      a[1..-1]
    }
    ary.compact!
    ary.map! {|a| a.to_i * UNIT} # ms になおす
    @raw = ary

    @format = nil
    @format ||= SonyFormat.parse(@raw.dup)
    @format ||= NECFormat.parse(@raw.dup)
    @format ||= JVCFormat.parse(@raw.dup)
    @format ||= DaikinFormat.parse(@raw.dup)
   #@format ||= KadenkyoFormat.parse(@raw.dup)
    @format ||= RawFormat.parse(@raw.dup)
    @format
  end

  def dump
    @format.dump
  end

  def verbose
    begin
      @format.verbose if @format.respond_to?(:verbose)
    rescue => e
      puts e
      puts e.backtrace
    end
  end

  def self.make_send_data(str)
    str = str.sub(/#.*$/,"").strip
    ary = SonyFormat.make_send_ary(str) ||
          NECFormat.make_send_ary(str) ||
          JVCFormat.make_send_ary(str) ||
          DaikinFormat.make_send_ary(str) ||
          RawFormat.make_send_ary(str) ||
          nil
    return nil if ary.nil?
    i=0
    ary.map{|a| "#{(i+=1)&1 == 1 ? 'H' : 'L'}#{(a/UNIT).round}"}.join(",")
  end
end
