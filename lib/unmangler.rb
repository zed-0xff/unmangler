require 'unmangler/string_ptr'
require 'unmangler/base'
require 'unmangler/version'
require 'unmangler/borland'
require 'unmangler/msvc'

module Unmangler
  class << self
    def unmangle name, args={}
      if name[0] == "@"
        Unmangler::Borland.safe_unmangle name, args
        # TODO: check if result is same as input
        # and try to unmangle with MS if it is
      elsif name[0] == '?'
        Unmangler::MSVC.safe_unmangle name, args
      elsif name[0,2] == '_Z'
        # GCC ?
        name
      else
        # return original name
        name
      end
    end
  end
end
