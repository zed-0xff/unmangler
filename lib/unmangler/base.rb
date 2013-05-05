module Unmangler
  class Base
    def isdigit c
      c =~ /\A\d\Z/
    end

    def assert cond
      raise unless cond
    end

    # same as 'unmangle', but catches all exceptions and returns original name
    # if can not unmangle
    def safe_unmangle name, *args
      unmangle name, *args
    rescue
      name
    end

    def self.unmangle *args
      new.unmangle(*args)
    end

    def self.safe_unmangle *args
      new.safe_unmangle(*args)
    end
  end
end
