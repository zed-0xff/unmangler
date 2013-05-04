module Unmangler
  class Base
    def isdigit c
      c =~ /\A\d\Z/
    end

    def assert cond
      raise unless cond
    end
  end
end
