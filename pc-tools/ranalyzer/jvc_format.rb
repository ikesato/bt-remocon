# -*- coding: utf-8 -*-

require "int_ary"

# T:0.51556ms (1T=97)
# Leader : H16T L8T
# 0      : H1T L1T
# 1      : H1T L3T
# bitlen : 16,32
class JVCFormat
  T = 0.51556 # [ms]
  FRAME_CYCLE = 45.0 # リーダを含まない1フレームの長さ（この値以上ならOK） [ms]
  NAME = "JVC"

  def self.parse(raw)
    i = JVCFormat.new
    return i if i._parse(raw)
    nil
  end

  def _parse(raw)
    return false if raw.length < 2+16
    return read_frame(raw)
  end

  def dump
    t = sprintf("%.3f", @data[:t])
    bitlen = @data[:bit_length]
    cycle = sprintf("%.1f", @data[:cycle])
    bytelen = (bitlen+8-1)/8

    frames = []
    @data[:frames].each {|f|
      a = f.to_a
      a = (a + [0]*(bytelen-a.length))
      frames << a.map {|i| sprintf("%02x",i)}.join(" ")
    }
    "#{NAME} T=#{t}[ms] CYCLE=#{cycle}[ms] #{bitlen}bit [#{frames.join(", ")}]"
  end

  def self.make_send_ary(str)
    return false if str !~ /#{NAME} T=([\d\.]+)\[ms\] CYCLE=([\d\.]+)\[ms\] (\d+)bit \[([\da-f ,]+)\]/

    t = $1.to_f
    cycle = $2.to_f
    bitlen = $3.to_i # bit length
    ary = $4.split(",").map{|m| m.strip}

    frames = []
    frames << 16*t
    frames << 8*t
    bitpos=0
    frame=[]
    ary.each {|v|
      frame=[]
      code = v.split(" ").compact.map{|a| a.hex}.to_num
      bitlen.times {|i|
        # hi
        frame << 1*t
        # lo
        if code & (1 << i) != 0
          frame << 3*t
        else
          frame << 1*t
        end
      }
      frame << 1*t
      frame << cycle - frame.inject(0){|sum,i| sum+i}
      frames += frame
    }
    frames
  end

  private
  def read_frame(raw)
    @data = {:t=>0, :bit_length=>0, :frames=>[], :cycle=>0}
    cycles = []
    bits_length = []
    tsum = 0
    tcount = 0

    leader = [raw.shift, raw.shift]
    return false if (16*T - leader[0]).abs/16*T > 0.1
    return false if (8*T - leader[1]).abs/8*T > 0.1
    tsum += leader[0]+leader[1]
    tcount += 16+8

    while raw.length > 0
      values, cycle, bitlen, _tsum, _tcount = read_code(raw)
      return false if values.nil?
      @data[:frames] << values
      tsum += _tsum
      tcount += _tcount
      cycles << cycle unless cycle.nil?
      bits_length << bitlen
    end

    @data[:bit_length] = bits_length.inject(0){|sum, i| sum + i}/bits_length.length
    return false if @data[:bit_length] != bits_length[0] #全bit長が同じであること
    @data[:t] = tsum / tcount

    if cycles.length > 0
      @data[:cycle] = cycles.inject(0){|sum, cycle|
        return false if cycle < FRAME_CYCLE*0.1
        sum + cycle
      } / cycles.length
    else
      @data[:cycle] = FRAME_CYCLE
    end
    return true
  end

  def read_code(raw)
    count = 0
    values = []
    bit = 0
    tsum = 0
    tcount = 0
    cycle = 0
    while raw.length >= 2
      cycle += raw[0]+raw[1]
      hi = raw.shift
      lo = raw.shift
      return nil if (1*T - hi).abs / 1*T > 0.1
      tsum += hi
      tcount += 1

      v = nil
      if (1*T - lo).abs / 1*T < 0.1
        v = 0
        tsum += lo
        tcount += 1
      elsif (3*T - lo).abs / 3*T < 0.1
        v = 1
        tsum += lo
        tcount += 3
      end

      if v==1
        bit |= (1 << (count%8))
      end

      if (count+1)%8 == 0
        values << bit
        bit = 0
      end

      if v.nil?
        if count==16 || count==32
          # 1フレーム終わり
          values << bit if count%8 != 0
          cycle=nil if raw.length==0
          return values, cycle, count, tsum, tcount
        else
          return nil
        end
      end
      count += 1
    end
    nil
  end
end
