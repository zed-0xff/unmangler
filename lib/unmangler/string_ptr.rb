#!/usr/bin/env ruby

class StringPtr
  attr_accessor :string, :pos

  def initialize s=nil, pos=0
    case s
    when String
      @string = s
      @pos = pos
    when StringPtr
      @string = s.string
      @pos = s.pos + pos
    when NilClass
      @string = nil
      @pos = pos
    else
      raise "invalid s: #{s.inspect}"
    end
  end

  def [] pos, len=nil
    if t = @string[@pos..-1]
      if len
        t[pos, len]
      else
        t[pos]
      end
    else
      nil
    end
  end

  def []= pos, x, y=nil
    if y
      # s[10, 3] = 'abc'
      @string[@pos+pos, x] = y
    elsif pos.is_a?(Range)
      range = pos
      if range.end > 0
        # s[10..12] = 'abc'
        @string[Range.new(range.begin+@pos, range.end+@pos)] = x
      else
        if range.begin >= 0
          # s[10..-1] = 'abc'
          @string[Range.new(range.begin+@pos, range.end)] = x
        else
          # s[-3..-1] = 'abc'
          @string[range] = x
        end
      end
    else
      # s[10] = 'a'
      @string[@pos+pos] = x
    end
  end

  def << s
    @string[@pos, s.size] = s
    @pos += s.size
  end

  def index needle
    @string[@pos..-1].index(needle)
  end

  def =~ re
    @string[@pos..-1] =~ re
  end

  def inc!; @pos+=1; end
  def dec!; @pos-=1; end

  def trim!
    return unless @string
    if idx = @string.index("\x00")
      @string[idx..-1] = ''
      @pos = @string.size if @pos > @string.size
    end
  end

  def + n
    self.class.new @string, @pos+n
  end

  def - x
    case x
    when Numeric
      # shift pointer
      self.class.new @string, @pos-x
    when StringPtr
      # return diff btw 2 ptrs
      raise "subtracting different pointers" if self.string != x.string
      @pos - x.pos
    end
  end
end

if $0 == __FILE__
  ptr = StringPtr.new("foo")
  p ptr[0]
  p ptr[1]
  p ptr
  ptr += 1
  p ptr
  p ptr[0]

  p2 = ptr+4
  p ptr-p2
  p p2-ptr
  p ptr-1
end
