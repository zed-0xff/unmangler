require 'unmangler/base'
require 'unmangler/version'
require 'unmangler/borland'
require 'unmangler/msvc'

module Unmangler
  class << self
    def unmangle name, args={}
      if name[0,1] == "@"
        Unmangler::Borland.safe_unmangle name, args
        # TODO: check if result is same as input
        # and try to unmangle with MS if it is
      elsif name[0,2] == '_Z'
        # GCC ?
        name
      elsif name[0,1] == '?'
        # MS ?
        name
      else
        # return original name
        name
      end
    end
  end
end
