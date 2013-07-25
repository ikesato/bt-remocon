class Integer
  def to_a
    v=self
    ret = []
    begin
      ret << (v&0xff)
      v >>= 8
    end while v!=0
    ret
  end

  def to_hex
    return sprintf("%02xh",self) if self < (1 << 8)
    return sprintf("%04xh",self) if self < (1 << 16)
    return sprintf("%08xh",self) if self < (1 << 32)
    sprintf("%xh",self)
  end

  def to_bin
    a=[]
    i=0
    if self < (1 << 8)
      e = 0xff
    elsif self < (1 << 16)
      e = 0xffff
    else
      e = 0xffffffff
    end
    while (1 << i) < e
      a << ((self & (1 << i)) != 0 ? 1 : 0)
      i+=1
    end
    a.reverse.join
  end
end

class Array
  def to_num
    ret = 0
    count=0
    self.each {|v|
      ret += (v << count)
      count += 8
    }
    ret
  end
  def to_hex
    self.map{|m|
      if m.kind_of?(Array)
        "[#{m.to_hex}]"
      elsif m.kind_of?(Integer)
        sprintf("%02x",m)
      else
        m.class
      end
    }.join(" ")
  end

  def to_bin
    self.map{|m|
      if m.kind_of?(Array)
        "[#{m.to_bin}]"
      elsif m.kind_of?(Integer)
        m.to_bin
      else
        m.class
      end
    }.join(" ")
  end
end

class String
  def to_a_from_hex
    a = split(" ")
    a.map {|m|
      m.hex
    }
  end
end

#p [1,2].to_num
