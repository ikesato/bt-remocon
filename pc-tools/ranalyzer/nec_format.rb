# -*- coding: utf-8 -*-

require "int_ary"

# T:0.56ms (1T=105)
# Leader : H16T L8T
# 0      : H1T L1T
# 1      : H1T L3T
# bitlen : 32,42
class NECFormat
  T = 0.56 # [ms]
  FRAME_CYCLE = 108.0 # 1フレームの長さ [ms]
  NAME = "NEC"
  REPEATER4T = "REP4T"
  REPEATER8T = "REP8T"

  def self.parse(raw)
    i = NECFormat.new
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
      if f==REPEATER4T || f==REPEATER8T
        frames << f
      else
        a = f.to_a
        a = (a + [0]*(bytelen-a.length))
        frames << a.map {|i| sprintf("%02x",i)}.join(" ")
      end
    }
    "#{NAME} T=#{t}[ms] #{bitlen}bit [#{frames.join(", ")}]"
  end

  def self.make_send_ary(str)
    return false if str !~ /#{NAME} T=([\d\.]+)\[ms\] (\d+)bit \[((?:[\da-f ,]|#{REPEATER4T}|#{REPEATER8T})+)\]/

    t = $1.to_f
    bitlen = $2.to_i # bit length
    ary = $3.split(",").map{|m| m.strip}

    frames = []
    bitpos=0
    frame=[]
    ary.each {|v|
      frame=[]
      if v==REPEATER4T
        frame << 16*t
        frame << 4*t
        frame << 1*t
        frame << (FRAME_CYCLE - frame.inject(0){|sum,i| sum+i})
      elsif v==REPEATER8T
        frame << 16*t
        frame << 8*t
        frame << 1*t
        frame << (FRAME_CYCLE - frame.inject(0){|sum,i| sum+i})
      else
        frame << 16*t
        frame << 8*t
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
        frame << FRAME_CYCLE - frame.inject(0){|sum,i| sum+i}
      end
      frames += frame
    }
    frames
  end

  private
  def read_frame(raw)
    @data = {:t=>0, :bit_length=>0, :frames=>[]}
    frame_cycle = []
    bits_length = []
    tsum = 0
    tcount = 0

    while raw.length >= 2
      cycle = raw[0]+raw[1]
      leader = [raw.shift, raw.shift]

      if (16*T - leader[0]).abs/16*T < 0.1 &&
         (8*T - leader[1]).abs/8*T < 0.1
        tsum += leader[0]+leader[1]
        tcount += 16+8
        values, _cycle, bitlen, _tsum, _tcount = read_code(raw,cycle)
        return false if values.nil?
        @data[:frames] << values
        unless _cycle.nil?
          tsum += _tsum
          tcount += _tcount
          frame_cycle << _cycle + cycle
        end
        bits_length << bitlen unless bitlen.nil?
      elsif (16*T - leader[0]).abs/16*T < 0.1 &&
            (4*T - leader[1]).abs/4*T < 0.1
        tsum += leader[0]+leader[1]
        tcount += 16+4
        cycle = read_repeater(raw,cycle)
        return false if cycle.nil?
        @data[:frames] << REPEATER4T
        frame_cycle << cycle
      else
        return false
      end
    end

    @data[:bit_length] = bits_length.inject(0){|sum, i| sum + i}/bits_length.length
    return false if @data[:bit_length] != bits_length[0] #全bit長が同じであること
    @data[:t] = tsum / tcount

    if frame_cycle.length>1
      frame_cycle.each {|f|
        return false if (FRAME_CYCLE - f).abs/FRAME_CYCLE >= 0.1
      }
    end
    return true
  end

  def read_code(raw,frame_leader)
    count = 0
    values = []
    bit = 0
    tsum = 0
    tcount = 0
    cycle = 0;
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
        if count==32 || count==42
          # 1フレーム終わり
          values << bit if count%8 != 0
          return values, cycle, count, tsum, tcount
        else
          if count==0
            # leader が同じでリピータの場合がある
            if raw.empty?
              return REPEATER8T, nil, nil
            end
            cycle = read_repeater([hi,lo],frame_leader,true)
            unless cycle.nil?
              return REPEATER8T, cycle, nil, tsum, tcount
            end
          end
          return nil
        end
      end
      count += 1
    end
    nil
  end

  def read_repeater(raw,frame_leader,force_check=false)
    return nil if raw.length < 2
    hi = raw.shift
    lo = raw.shift
    cycle = hi+lo
    return nil if (1*T - hi).abs / 1*T > 0.1
    if raw.length>0 || force_check
      # データが終端でなければ長さチェックを行う
      return nil if (FRAME_CYCLE - (cycle+frame_leader)).abs / FRAME_CYCLE > 0.1
      cycle + frame_leader
    else
      FRAME_CYCLE
    end
  end
end
