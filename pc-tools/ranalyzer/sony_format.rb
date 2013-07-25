# -*- coding: utf-8 -*-

require "int_ary"

# T:0.6ms 
# Leader : H4T L1T
# 0      : H1T L1T
# 1      : H2T L1T
class SonyFormat
  T = 0.6 # [ms]
  FRAME_CYCLE = 45.0 # 1フレームの長さ [ms]
  NAME = "SONY"

  def self.parse(raw)
    i = SonyFormat.new
    return i if i._parse(raw)    
    nil
  end

  def _parse(raw)
    return false if raw.length < 2+8
    return read_frame(raw)
  end

  def dump
    t = sprintf("%.3f",@data[:t])
    bitlen = @data[:bit_length]
    bytelen = (bitlen+8-1)/8

    frames = []
    @data[:frames].each {|f|
      a = f.to_a
      a = (a + [0]*(bytelen-a.length))
      frames << a.map {|i| sprintf("%02x",i)}.join(" ")
    }
    "#{NAME} T=#{t}[ms] #{bitlen}bit [#{frames.join(", ")}]"
  end

  def self.make_send_ary(str)
    return false if str !~ /#{NAME} T=([\d\.]+)\[ms\] (\d+)bit \[([\da-f, ]+)\]/
    t = $1.to_f
    bitlen = $2.to_i # bit length
    ary = $3.split(",")
    frames = ary.map{|s|
      s.split(" ").compact.map{|v| v.hex}
    }

    ret = []
    frames.each {|frame|
      v = frame.to_num
      frame = []
      # leader
      frame << 4*t
      frame << 1*t
      bitlen.times {|i|
        # hi
        if v & (1 << i) != 0
          frame << 2*t
        else
          frame << 1*t
        end
        # lo
        frame << 1*t
      }
      fill = FRAME_CYCLE - frame.inject(0){|sum,i| sum+i}
      if fill > 0
        frame[frame.length-1] = frame.last + fill
      end
      ret += frame
    }
    
    ret
  end

  private
  def read_frame(raw)
    @data = {:t=>0, :bit_length=>0, :frames=>[]}
    frame_cycle = []
    bits_length = []
    tsum = 0
    tcount = 0

    while raw.length >= 2
      frame = 0
      frame += raw[0]+raw[1]
      leader = [raw.shift, raw.shift]
      return false if (4*T - leader[0]).abs/4*T >= 0.1
      return false if (1*T - leader[1]).abs/1*T >= 0.1
      tsum += leader[0]+leader[1]
      tcount += 5

      count = 0
      bits = 0
      readed = false
      while raw.length >= 2
        frame += raw[0]+raw[1]
        hi = raw.shift
        lo = raw.shift
        tsum += hi
        if (1*T - hi).abs / 1*T < 0.1
          tcount += 1
        elsif (2*T - hi).abs / 2*T < 0.1
          bits |= (1 << count)
          tcount += 2
        else
          return false
        end
        count += 1

        if (1*T - lo).abs / 1*T < 0.1
          tsum += lo
          tcount += 1
          ;
        elsif count==12 || count==15 || count==20
          # 1フレーム終わり
          @data[:frames] << bits
          frame_cycle << frame
          bits_length << count
          readed = true
          break
        else
          return false
        end
      end
      return false if readed==false
    end
    @data[:bit_length] = bits_length.inject(0){|sum, i| sum + i}/bits_length.length
    return false if @data[:bit_length] != bits_length[0] #全bit長が同じであること
    @data[:t] = tsum / tcount
    return true
  end
end
