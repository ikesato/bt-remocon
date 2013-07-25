# -*- coding: utf-8 -*-

require "int_ary"
require "daikin_remocon"

# T:0.4266666ms (1T=80)
#
# format:
#   header(10bit), sepa0,
#   body0(8byte), sepa,
#   body1(8byte), sepa,
#   body2(19byte)
#   trailer(hi only)
#
#   or
#
#   header(10bit), sepa0,
#   body0(8byte)
# 
# 0      : H1T L1T
# 1      : H1T L3T
class DaikinFormat
  T = 0.426666 # [ms]
  NAME = "DAIKIN"

  def self.parse(raw)
    i = DaikinFormat.new
    return i if i._parse(raw)
    nil
  end

  def _parse(raw)
    unless raw.length == 10+4+ 128+4+ 128+4 + 128*2 + 48 + 2 ||
           raw.length == 10+4+ 128+ 2
      return false
    end
    return read_frame(raw)
  end

  def dump
    t = sprintf("%.3f", @data[:t])
    frames = @data[:frames].map {|f|
      f.map{|v| sprintf("%02x",v)}.join(" ")
    }
    "#{NAME} T=#{t}[ms] [#{frames.join(", ")}]"
  end

  def verbose
    DaikinRemocon.new(@data).report
  end

  def self.make_send_ary(str)
    return false if str !~ /#{NAME} T=([\d\.]+)\[ms\] \[([\da-f ,]+)\]/

    t = $1.to_f
    ary = $2.split(",").map{|m| m.strip}

    frames = []
    frames += [t]*10
    frames += [0.45, 25.32, 3.48, 1.71] # separator0
    frames += make_body(ary[0], t, 64)
    if ary.length>1
      frames += [0.44, 34.68, 3.48, 1.71] # separator
      frames += make_body(ary[1], t, 64)
      frames += [0.44, 34.68, 3.48, 1.71] # separator
      frames += make_body(ary[2], t, 19*8)
    end
    frames += [1*T] # trailer
    frames
  end

  private
  def self.make_body(codes, t, bitlen)
    n = codes.split(" ").map{|a| a.hex}.to_num
    frame = []
    bitlen.times {|i|
      # hi
      frame << 1*t
      # lo
      if n & (1 << i) != 0
        frame << 3*t
      else
        frame << 1*t
      end
    }
    return frame
  end

  def read_frame(raw)
    @data = {:t=>0, :frames=>[]}
    tsum = 0
    tcount = 0

    # header
    10.times {|i|
      v=raw.shift
      tsum += v
      tcount += 1
      return false if (1*T - v).abs/1*T > 0.2
    }

    # separator0
    # H084,L4748,H652,L321 => [0.45, 25.32, 3.48, 1.71]
    v=raw.shift
    tsum += v
    tcount += 1
    return false if (1*T - v).abs/1*T > 0.2
    v=raw.shift
    return false if (25.32 - v).abs/25.32 > 0.1
    v=raw.shift
    return false if (3.48 - v).abs/3.48 > 0.1
    v=raw.shift
    return false if (1.71 - v).abs/1.71 > 0.1

    # body0
    code, _tsum, _tcount = read_code(raw,64)
    return false if code.nil?
    tsum += _tsum
    tcount += _tcount
    @data[:frames] << code

    # separator
    v=raw[0]
    rest = raw.length
    if read_separator(raw)
      ;
    elsif (1*T - v).abs/1*T <= 0.2 && rest == 2
      # 終わり
      @data[:t] = tsum / tcount
      return true
    else
      return false
    end

    # body1
    code, _tsum, _tcount = read_code(raw,64)
    return false if code.nil?
    tsum += _tsum
    tcount += _tcount
    @data[:frames] << code

    # separator
    return false if read_separator(raw)==false

    # body2
    code, _tsum, _tcount = read_code(raw,19*8)
    return false if code.nil?
    tsum += _tsum
    tcount += _tcount
    @data[:frames] << code


    # trailer
    v=raw.shift
    tsum += v
    tcount += 1
    return false if (1*T - v).abs/1*T > 0.2
    v=raw.shift
    return false if raw.length>0

    @data[:t] = tsum / tcount
    return true
  end

  def read_code(raw, bitlen)
    tsum = tcount = 0
    bit=0
    bitlen.times{|i|
      hi = raw.shift
      lo = raw.shift
      return nil if (1*T - hi).abs/1*T > 0.2
      tsum += hi+lo
      tcount += 1
      if (1*T - lo).abs/1*T <= 0.2
        tcount += 1
      elsif (3*T - lo).abs/3*T <= 0.2
        tcount += 3
        bit |= (1 << i)
      else
        return nil
      end
    }
    a = bit.to_a
    return (a + [0]*(a.length - bitlen/8)), tsum, tcount
  end

  # separator 0
  # H083,L6502,H652,L320 => [0.44, 34.68, 3.48, 1.71]
  def read_separator(raw)
    v=raw.shift
    return false if (1*T - v).abs/1*T > 0.2
    v=raw.shift
    return false if (34.68 - v).abs/34.68 > 0.1
    v=raw.shift
    return false if (3.48 - v).abs/3.48 > 0.1
    v=raw.shift
    return false if (1.71 - v).abs/1.71 > 0.1
    true
  end
end
