# -*- coding: utf-8 -*-

require "int_ary"

class DaikinRemocon
  attr_accessor :tcycle # data[:t] を格納
  attr_accessor :bodies # 配列, data[:frames] をそのまま格納
  attr_accessor :body0_only

  attr_accessor :power # true:on false:off
  attr_accessor :reset_mode # true:on false:off
  attr_accessor :clean_filter # true:on false:off
  attr_accessor :inner_clean_mode # true:on false:off
  attr_accessor :kaze_nice # true:on false:off
  attr_accessor :timer_auto_pon_mode # true:on false:off
  attr_accessor :timer_auto_poff_mode # true:on false:off
  attr_accessor :air_mode # 0:標準(自動) 1:? 2:標準(ドライ) 3:冷房 4:暖房 5:? 6:送風 7:?
  attr_accessor :temperature # 温度
  attr_accessor :air_direction_mode # true:風向きon false:風向きoff
  attr_accessor :air_volume # 3-7:風量1-5  0xa:風量自動 0xb:しずか
  attr_accessor :timer_on_after # タイマー入 N時間後電源on
  attr_accessor :timer_off_after # タイマー切 N時間後電源off
  attr_accessor :healthful_mode # 健康冷房

  def initialize(data)
    from_raw_data(data)
    verify!(data)
  end

  def from_raw_data(data)
    self.tcycle = data[:t]
    self.bodies = data[:frames].dup
    self.body0_only = data[:frames].count <= 1

    parse_body0(bodies[0])
    check_sum(bodies[0])

    unless self.body0_only
      parse_body1(bodies[1])
      parse_body2(bodies[2])
      check_sum(bodies[1])
      check_sum(bodies[2])
    end
  end

  def verify!(data)
    v = to_raw_data
    if v != data
      raise "verify failed\nt=>#{v[:t]}\nframes=>#{v[:frames].to_hex}\n#{report}"
    end
  end
  
  def to_raw_data
    ret = {}
    ret[:t] = tcycle
    ret[:frames] = []

    # body0
    body0 = [0x11, 0xda, 0x27, 0x00]
    body0 << (self.body0_only ? 0x84 : 0xc5)
    if self.body0_only==false
      body0 << 0
    elsif self.reset_mode && !self.clean_filter
      body0 << 0x13
    elsif !self.reset_mode && self.clean_filter
      body0 << 0x14
    end
    if self.body0_only
      body0 << 0
    else
      body0 << (0x20 |
                (self.inner_clean_mode ? 0x8 : 0) |
                (self.kaze_nice ? 0x10 : 0))
    end
    body0 << (body0.inject(:+) & 0xff)
    ret[:frames] << body0

    return ret if self.body0_only

    # body1
    ret[:frames] << [0x11, 0xda, 0x27, 0x00, 0x42, 0x00, 0x00, 0x54]

    # body2
    body2 = [0x11, 0xda, 0x27, 0x00, 0x00]

    # body2:byte5
    b = 0x08
    b |= 0x01 if self.power
    b |= 0x02 if self.timer_auto_pon_mode
    b |= 0x04 if self.timer_auto_poff_mode
    b |= (self.air_mode << 4)
    body2 << b

    # body2:byte6,7
    case self.air_mode
    when 0, 2 # 標準(ドライ) / 標準(自動)
      b = 0xc0
      bb = self.temperature
      bb += 16 if bb < 0
      b |= (bb << 1)
      body2 << b
      body2 << 0x80
    when 3, 4 # 冷房, 暖房
      body2 << (self.temperature << 1)
      body2 << 0x00
    when 6 # 送風
      body2 << 0x32
      body2 << 0x00
    end

    # body2:byte8
    b = 0
    b |= 0xf if self.air_direction_mode
    b |= self.air_volume << 4
    body2 << b

    # body2:byte9
    body2 << 0x00

    # body2:byte10,11,12
    b = [0,0,0]
    if !self.timer_auto_pon_mode
      b[0] |= 0
      b[1] |= (0x8>>2)
      b[1] |= (1 << 2)
    else
      h = self.timer_on_after - 1
      b[0] |= ((16-(h+1)) << 2)
      b[0] |= ((h&0x3) << 6)
      b[1] |= ((h&0xc) >> 2)
    end

    if !self.timer_auto_poff_mode
      b[2] |= (0x8 << 2)
      b[2] |= (1 << 6)
    else
      h = self.timer_off_after - 1
      ih = (16-(h+1))
      b[1] |= ((ih&0x3) << 6)
      b[2] |= ((ih&0xc) >> 2)
      b[2] |= (h << 2)
    end
    body2 += b

    # body2:byte13
    body2 << (self.healthful_mode ? 0x08 : 0)

    # body2:byte14-17
    body2 += [0x00, 0xc1, 0x80, 0x00]

    # body2:byte18
    body2 << calc_check_sum(body2)

    # body2
    ret[:frames] << body2
    ret
  end

  def report
    ret = <<EOF
t                    : #{sprintf("%.3f",tcycle)}[ms]
body0_only           : #{body0_only}
reset_mode           : #{reset_mode}
clean_filter         : #{clean_filter}
inner_clean_mode     : #{inner_clean_mode}
kaze_nice            : #{kaze_nice}
EOF
    if body0_only==false
      ret += <<EOF
power                : #{power}
timer_auto_pon_mode  : #{timer_auto_pon_mode}
timer_auto_poff_mode : #{timer_auto_poff_mode}
air_mode             : #{report_air_mode(air_mode)}
temperature          : #{temperature}
air_direction_mode   : #{air_direction_mode}
air_volume           : #{report_air_volume(air_volume)}
timer_on_after       : #{timer_on_after}
timer_off_after      : #{timer_off_after}
healthful_mode       : #{healthful_mode}
EOF
    end
    ret
  end

  private
  def check_sum(ary)
    sum = ary[0...ary.length-1].inject(:+)
    if ary.last != (sum & 0xff)
      raise "check sum doesn't match [#{ary.to_hex}]"
    end
  end

  def calc_check_sum(ary)
    ary.inject(:+) & 0xff
  end

  def parse_body0(body0)
    if body0[0,4] != [0x11, 0xda, 0x27, 0x00]
      raise "invalid body0 byte0-4 format [#{body0[0,4].to_hex}]"
    end
    if body0[4] == 0xc5
      raise "need body1 and body2 [#{body0.to_hex}]" if self.body0_only == true
    elsif body0[4] == 0x84
      raise "body1 and body2 doesn't need [#{body0.to_hex}]" if self.body0_only == false
    else
      raise "invalid body0 byte4 [#{body0.to_hex}]"
    end

    if body0[5] == 0
      raise "body0 byte5 must be 0x00 [#{body0.to_hex}]" if self.body0_only == true
      self.reset_mode = false
      self.clean_filter = false
    else
      if body0[5] == 0x13
        self.reset_mode = true
        self.clean_filter = false
      elsif body0[5] == 0x14
        self.reset_mode = false
        self.clean_filter = true
      else
        raise "body0 byte5 must be 0x13 or 0x14 [#{body0.to_hex}]"
      end
    end

    if body0[4] == 0x84
      if body0[6] != 0x00
        raise "invalid body0 format (84h) [#{body0.to_hex}]"
      end
    else
      if body0[6] & 0xe7 != 0x20
        raise "invalid body0 format (c5h) [#{body0.to_hex}]"
      end
    end
    self.inner_clean_mode = (body0[6] & 0x8 != 0)
    self.kaze_nice = (body0[6] & 0x10 != 0)
  end

  def parse_body1(body1)
    if body1 != [0x11, 0xda, 0x27, 0x00, 0x42, 0x00, 0x00, 0x54]
      raise "invalid body1 format [#{body1.to_hex}]"
    end
  end

  def parse_body2(body2)
    # byte0-4
    if body2[0..4] != [0x11, 0xda, 0x27, 0x00, 0x00]
      raise "ivalid format byte0-4 [#{body2[0..4].to_hex}]"
    end

    # byte5
    self.power = (body2[5] & 0x1 != 0)
    if body2[5] & 0x88 != 0x08
      raise "invalid format byte5.3,7 [#{body2[5].to_hex}]"
    end
    self.timer_auto_pon_mode  = (body2[5] & 0x2 != 0)
    self.timer_auto_poff_mode = (body2[5] & 0x4 != 0)
    self.air_mode = ((body2[5] >> 4) & 0x7)
    unless [0,2,3,4,6].include?(self.air_mode)
      raise "invalid format byte5.4-6 [#{body2[5].to_hex}]"
    end

    # byte6,7
    case self.air_mode
    when 0, 2 # 標準(ドライ) / 標準(自動)
      raise "invalid format byte6. must be 0xc0. [#{body2[6].to_hex}]" if body2[6] & 0xe1 != 0xc0
      raise "invalid format byte7. must be 0x80. [#{body2[7].to_hex}]" if body2[7] != 0x80
      self.temperature = body2[6] >> 1 & 0xf
      self.temperature -= 16 if self.temperature > 5
      unless (-5..5).include?(self.temperature)
        raise "temparature is out of range. must be (-5..5). [#{body2[6].to_hex}]"
      end
    when 3, 4 # 冷房, 暖房
      raise "invalid format byte6. must be 0x00. [#{body2[6].to_hex}]" if body2[6] & 0x81 != 0x00
      raise "invalid format byte7. must be 0x00. [#{body2[6].to_hex}]" if body2[7] != 0x00
      self.temperature = body2[6] >> 1 & 0x3f
      if self.air_mode==4 && !(14..30).include?(self.temperature) # 暖房
        raise "temparature is out of range. must be (14..30). [#{body2[6].to_hex}]"
      end
      if self.air_mode==3 && !(18..32).include?(self.temperature) # 冷房
        raise "temparature is out of range. must be (18..32). [#{body2[6].to_hex}]"
      end
    when 6 # 送風
      self.temperature = nil
      raise "invalid format byte6. must be 0x32. [#{body2[6].to_hex}]" if body2[6] != 0x32
      raise "invalid format byte7. must be 0x00. [#{body2[7].to_hex}]" if body2[7] != 0x00
    end

    # byte8
    #   bit0-3 => 風向き 0h:オフ fh:オン
    #   bit4-7 => B'0011:風量1 B'0100:風量2 ... B'0111:風量5 B'1010:風量自動 B'1011:しずか
    if body2[8]&0x0f == 0
      self.air_direction_mode = false
    elsif body2[8]&0x0f == 0xf
      self.air_direction_mode = true
    else
      raise "invalid format byte8. must be 0 or f. [#{body2[8].to_hex}]"
    end
    self.air_volume = (body2[8] >> 4) & 0xf
    unless [0x3,0x4,0x5,0x6,0x7,0xa,0xb].include?(self.air_volume)
      raise "invalid format byte8. [#{body2[8].to_hex}]"
    end

    #byte9
    if body2[9] != 0
      raise "invalid format byte9. [#{body2[9].to_hex}]"
    end

    #byte10,11,12
    #タイマー入、タイマー切の時間
    if body2[10]&0x3 != 0 || body2[11]&0x38 != 0 || body2[12]&0x80 != 0
p "hogeeeeee"
p [body2[10]&0x3, body2[11]&0x38, body2[12]&0x80].to_hex
      raise "invalid format byte10-12 [#{body2[10,3].to_hex}]"
    end
    #タイマー入
    ihour = (body2[10] >> 2) & 0xf
    hour  = ((body2[10] >> 6) & 0x3) + ((body2[11] & 0x3) << 2)
    flg   = (body2[11] >> 2) & 0x1
    if !self.timer_auto_pon_mode && (hour!=8 || ihour!=0 || flg!=1)
      raise "invalid timer on format(off) [#{[hour, ihour, flg]}]"
    end
    if self.timer_auto_pon_mode
      if 16-(hour+1) != ihour
        raise "invalid timer on format(on) [#{[hour, ihour, flg]}]"
      elsif !(1..12).include?(hour+1)
        raise "timer on hour is out of range (1..12) [#{hour}]"
      end
      self.timer_on_after = hour + 1
    else
      self.timer_on_after = nil
    end

    #タイマー切
    ihour = ((body2[11] >> 6) & 0x3) + ((body2[12] & 0x3) << 2)
    hour  = ((body2[12] >> 2) & 0xf)
    flg   = (body2[12] >> 6) & 0x1
    if !self.timer_auto_poff_mode && (hour!=8 || ihour!=0 || flg!=1)
      raise "invalid timer off format(off) [#{[hour, ihour, flg]}]"
    end
    if self.timer_auto_poff_mode
      if 16-(hour+1) != ihour
        raise "invalid timer off format(on) [#{[hour, ihour, flg]}]"
      elsif !(1..9).include?(hour+1)
        raise "timer off hour is out of range (1..12) [#{hour}]"
      end
      self.timer_off_after = hour + 1
    else
      self.timer_off_after = nil
    end

    # byte13 健康冷房
    if body2[13] == 0
      self.healthful_mode = false
    elsif body2[13] == 0x08
      self.healthful_mode = true
    else
# TODO:    DAIKIN T=0.425[ms] [11 da 27 00 c5 00 20 f7, 11 da 27 00 42 00 00 54, 11 da 27 00 00 49 3a 00 a0 00 3c 00 60 00 00 c1 a0 00 32] # 快眠1回 (運転中, 29度, 暖房, 風量自動, フィルター掃除, 快眠1時間後)  
      raise "invalid format byte13. [#{body2[13].to_hex}]"
    end
    if self.healthful_mode && self.air_volume!=0xa
      raise "invalid format. air_volume must be auto if healthful_mode is true."
    end

    # byte14-17
    if body2[14,4] != [0x00, 0xc1, 0x80, 0x00]
      raise "invalid format byte14-17. [#{body2[14,4].to_hex}]"
    end
  end

  def report_air_mode(a)
    v = "#{a} ("
    case a
    when 0
      v+="auto"
    when 2
      v+="dry"
    when 3
      v+="air-condition"
    when 4
      v+="heating"
    when 6
      v+="ventilation"
    else
      raise "invalid air_mode #{a.to_hex}"
    end
    v+=")"
  end

  def report_air_volume(a)
    case a
    when 0x3; "1"
    when 0x4; "2"
    when 0x5; "3"
    when 0x6; "4"
    when 0x7; "5"
    when 0xa; "auto"
    when 0xb; "silent"
    else
      raise "invalid air_volume #{a.to_hex}"
    end
  end
end
