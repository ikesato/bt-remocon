# -*- coding: utf-8 -*-

# 生データを表示するだけ
# 単位は ms
class RawFormat
  NAME = "raw"

  def initialize(raw)
    @raw = raw
  end
  def self.parse(raw)
    s=RawFormat.new(raw)
  end

  def dump
    "#{NAME} [#{@raw.map{|v| sprintf("%.3f",v)}.join(",")}]"
  end

  def self.make_send_ary(str)
    return false if str !~ /#{NAME} \[([\da-f\.,]+)\]/
    raw = $1.split(",").map{|v| v.to_f}
    raw
  end
end
