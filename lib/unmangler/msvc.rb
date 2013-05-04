#!/usr/bin/env ruby
require File.expand_path("base", File.dirname(__FILE__))

module Unmangler; end

class Unmangler::MSVC < Unmangler::Base

  UNDNAME_COMPLETE                 = 0x0000
  UNDNAME_NO_LEADING_UNDERSCORES   = 0x0001 # Don't show __ in calling convention
  UNDNAME_NO_MS_KEYWORDS           = 0x0002 # Don't show calling convention at all
  UNDNAME_NO_FUNCTION_RETURNS      = 0x0004 # Don't show function/method return value
  UNDNAME_NO_ALLOCATION_MODEL      = 0x0008
  UNDNAME_NO_ALLOCATION_LANGUAGE   = 0x0010
  UNDNAME_NO_MS_THISTYPE           = 0x0020
  UNDNAME_NO_CV_THISTYPE           = 0x0040
  UNDNAME_NO_THISTYPE              = 0x0060
  UNDNAME_NO_ACCESS_SPECIFIERS     = 0x0080 # Don't show access specifier = public/protected/private
  UNDNAME_NO_THROW_SIGNATURES      = 0x0100
  UNDNAME_NO_MEMBER_TYPE           = 0x0200 # Don't show static/virtual specifier
  UNDNAME_NO_RETURN_UDT_MODEL      = 0x0400
  UNDNAME_32_BIT_DECODE            = 0x0800
  UNDNAME_NAME_ONLY                = 0x1000 # Only report the variable/method name
  UNDNAME_NO_ARGUMENTS             = 0x2000 # Don't show method arguments
  UNDNAME_NO_SPECIAL_SYMS          = 0x4000
  UNDNAME_NO_COMPLEX_TYPE          = 0x8000

  class ParsedSymbol < Struct.new(
    :flags,          # (unsigned int) the UNDNAME_ flags used for demangling
    :current,        # (const char*)  pointer in input (mangled) string
    :result,         # (char*)        demangled string
    :names,          # (struct array) array of names for back reference
    :stack,          # (struct array) stack of parsed strings
    :alloc_list,     # (void*)        linked list of allocated blocks
    :avail_in_first  # (usigned int)  number of available bytes in head block
  )
    def initialize *args
      super
      self.names ||= []
      self.stack ||= []
    end
  end

  DataType = Struct.new :left, :right # char*

  def unmangle mangled, flags = UNDNAME_COMPLETE
    if flags & UNDNAME_NAME_ONLY != 0
      flags |= UNDNAME_NO_FUNCTION_RETURNS | UNDNAME_NO_ACCESS_SPECIFIERS |
        UNDNAME_NO_MEMBER_TYPE | UNDNAME_NO_ALLOCATION_LANGUAGE | UNDNAME_NO_COMPLEX_TYPE
    end

    sym = ParsedSymbol.new
    sym.flags   = flags
    sym.current = StringPtr.new(mangled)

    symbol_demangle(sym) ? sym.result.strip : mangled
  end

  def self.unmangle *args
    new.unmangle(*args)
  end

  private

#  def warn fmt, *args
#    STDERR.printf(fmt, *args)
#  end

  def err fmt, *args
    STDERR.printf(fmt, *args)
  rescue
    STDERR.puts "[!] #{fmt.strip.inspect}, #{args.inspect}"
  end
  alias :warn :err

  def symbol_demangle sym
    ret         = false
    do_after    = 0
    dashed_null = "--null--"

    catch(:done) do
      # seems wrong as name, as it demangles a simple data type
      if sym.flags & UNDNAME_NO_ARGUMENTS != 0
        ct = DataType.new
        if (demangle_datatype(sym, ct, nil, false))
          sym.result = sprintf("%s%s", ct.left, ct.right);
          ret = true
        end
        throw :done
      end # if

      # MS mangled names always begin with '?'
      return false unless sym.current[0] == '?'
      sym.current.inc!

      # Then function name or operator code
      if (sym.current[0] == '?' && (sym.current[1] != '$' || sym.current[2] == '?'))
          function_name = nil

          if (sym.current[1] == '$')
            do_after = 6
            sym.current += 2
          end

          # C++ operator code (one character, or two if the first is '_')
          case sym.current.inc_get!
          when '0'; do_after = 1
          when '1'; do_after = 2
          when '2'; function_name = "operator new"
          when '3'; function_name = "operator delete"
          when '4'; function_name = "operator="
          when '5'; function_name = "operator>>"
          when '6'; function_name = "operator<<"
          when '7'; function_name = "operator!"
          when '8'; function_name = "operator=="
          when '9'; function_name = "operator!="
          when 'A'; function_name = "operator[]"
          when 'B'; function_name = "operator "; do_after = 3
          when 'C'; function_name = "operator."
          when 'D'; function_name = "operator*"
          when 'E'; function_name = "operator++"
          when 'F'; function_name = "operator--"
          when 'G'; function_name = "operator-"
          when 'H'; function_name = "operator+"
          when 'I'; function_name = "operator&"
          when 'J'; function_name = "operator.*"
          when 'K'; function_name = "operator/"
          when 'L'; function_name = "operator%"
          when 'M'; function_name = "operator<"
          when 'N'; function_name = "operator<="
          when 'O'; function_name = "operator>"
          when 'P'; function_name = "operator>="
          when 'Q'; function_name = "operator,"
          when 'R'; function_name = "operator()"
          when 'S'; function_name = "operator~"
          when 'T'; function_name = "operator^"
          when 'U'; function_name = "operator|"
          when 'V'; function_name = "operator&&"
          when 'W'; function_name = "operator||"
          when 'X'; function_name = "operator*="
          when 'Y'; function_name = "operator+="
          when 'Z'; function_name = "operator-="
          when '_'
              case sym.current.inc_get!
              when '0'; function_name = "operator/="
              when '1'; function_name = "operator%="
              when '2'; function_name = "operator>>="
              when '3'; function_name = "operator<<="
              when '4'; function_name = "operator&="
              when '5'; function_name = "operator|="
              when '6'; function_name = "operator^="
              when '7'; function_name = "`vftable'"
              when '8'; function_name = "`vbtable'"
              when '9'; function_name = "`vcall'"
              when 'A'; function_name = "`typeof'"
              when 'B'; function_name = "`local static guard'"
              when 'C'; function_name = "`string'"; do_after = 4
              when 'D'; function_name = "`vbase destructor'"
              when 'E'; function_name = "`vector deleting destructor'"
              when 'F'; function_name = "`default constructor closure'"
              when 'G'; function_name = "`scalar deleting destructor'"
              when 'H'; function_name = "`vector constructor iterator'"
              when 'I'; function_name = "`vector destructor iterator'"
              when 'J'; function_name = "`vector vbase constructor iterator'"
              when 'K'; function_name = "`virtual displacement map'"
              when 'L'; function_name = "`eh vector constructor iterator'"
              when 'M'; function_name = "`eh vector destructor iterator'"
              when 'N'; function_name = "`eh vector vbase constructor iterator'"
              when 'O'; function_name = "`copy constructor closure'"
              when 'R'
                  sym.flags |= UNDNAME_NO_FUNCTION_RETURNS
                  case sym.current.inc_get!
                  when '0'
                    ct = DataType.new
                    pmt = []
                    sym.current.inc!
                    demangle_datatype(sym, ct, pmt, false)
                    function_name = sprintf("%s%s `RTTI Type Descriptor'", ct.left, ct.right)
                    sym.current.dec!
                  when '1'
                    sym.current.inc!
                    n1 = get_number(sym)
                    n2 = get_number(sym)
                    n3 = get_number(sym)
                    n4 = get_number(sym)
                    sym.current.dec!
                    function_name = sprintf("`RTTI Base Class Descriptor at (%s,%s,%s,%s)'", n1, n2, n3, n4)
                  when '2'; function_name = "`RTTI Base Class Array'"
                  when '3'; function_name = "`RTTI Class Hierarchy Descriptor'"
                  when '4'; function_name = "`RTTI Complete Object Locator'"
                  else
                    err("Unknown RTTI operator: _R%c\n", sym.current[0])
                  end # case sym.current.inc_get!
              when 'S'; function_name = "`local vftable'"
              when 'T'; function_name = "`local vftable constructor closure'"
              when 'U'; function_name = "operator new[]"
              when 'V'; function_name = "operator delete[]"
              when 'X'; function_name = "`placement delete closure'"
              when 'Y'; function_name = "`placement delete[] closure'"
              else
                  err("Unknown operator: _%c\n", sym.current[0])
                  return false
              end # case sym.current.inc_get!
          else
              # FIXME: Other operators
              err("Unknown operator: %c\n", sym.current[0])
              return false
          end # case sym.current.inc_get!

          sym.current.inc!

          case do_after
          when 1,2
            sym.stack << dashed_null
          when 4
            sym.result = function_name
            ret = true
            throw :done
          else
            if do_after == 6
              array_pmt = []
              if args = get_args(sym, array_pmt, false, '<', '>')
                function_name << args
              end
              sym.names = []
            end
            sym.stack << function_name
          end # case do_after

      elsif sym.current[0] == '$'
          # Strange construct, it's a name with a template argument list and that's all.
          sym.current.inc!
          ret = (sym.result = get_template_name(sym)) != nil
          throw :done
      elsif sym.current[0,2] == '?$'
          do_after = 5
      end

      # Either a class name, or '@' if the symbol is not a class member
      case sym.current[0]
      when '@'; sym.current.inc!
      when '$'; # do nothing
      else
        # Class the function is associated with, terminated by '@@'
        throw :done unless get_class(sym)
      end # case sym.current[0]

      case do_after
      when 1,2
        # it's time to set the member name for ctor & dtor
        throw :done if sym.stack.size <= 1 # ZZZ may be wrong
        if do_after == 1
          sym.stack[0] = sym.stack[1]
        else
          sym.stack[0] = "~" + sym.stack[1]
        end
        # ctors and dtors don't have return type
        sym.flags |= UNDNAME_NO_FUNCTION_RETURNS
      when 3
        sym.flags &= ~UNDNAME_NO_FUNCTION_RETURNS
      when 5
        sym.names.shift
      end # case do_after

      # Function/Data type and access level
      ret =
        case sym.current[0]
        when /\d/
          handle_data(sym)
        when /[A-Z]/
          handle_method(sym, do_after == 3)
        when '$'
          handle_template(sym)
        else
          false
        end
    end # catch(:done)

    if ret
      assert(sym.result)
    else
      warn("Failed at %s\n", sym.current[0..-1])
    end

    ret
  end

 # Attempt to demangle a C++ data type, which may be datatype.
 # a datatype type is made up of a number of simple types. e.g:
 # char** = (pointer to (pointer to (char)))

  def demangle_datatype(sym, ct, pmt_ref=nil, in_args=false)
    dt = nil
    add_pmt = true

    assert(ct)
    ct.left = ct.right = nil

    catch :done do
      case (dt = sym.current.get_inc!) #.tap{ |x| puts "[d] #{x}" }
      when '_'
          # MS type: __int8,__int16 etc
          ct.left = get_extended_type(sym.current.get_inc!)

      when *SIMPLE_TYPES.keys
          # Simple data types
          ct.left = get_simple_type(dt)
          add_pmt = false

      when 'T','U','V','Y'
          # union, struct, class, cointerface
          struct_name = type_name = nil

          throw :done unless struct_name = get_class_name(sym)

          if (sym.flags & UNDNAME_NO_COMPLEX_TYPE == 0)
              case (dt)
              when 'T'; type_name = "union "
              when 'U'; type_name = "struct "
              when 'V'; type_name = "class "
              when 'Y'; type_name = "cointerface "
              end
          end
          ct.left = sprintf("%s%s", type_name, struct_name)

      when '?'
          # not all the time is seems
          if in_args
              throw :done unless ptr = get_number(sym)
              ct.left = "`template-parameter-#{ptr}'"
          else
              throw :done unless get_modified_type(ct, sym, pmt_ref, '?', in_args)
          end

      when 'A','B'     # reference, volatile reference
          throw :done unless get_modified_type(ct, sym, pmt_ref, dt, in_args)

      when 'Q','R','S' # const pointer, volatile pointer, const volatile pointer
          throw :done unless get_modified_type(ct, sym, pmt_ref, in_args ? dt : 'P', in_args)

      when 'P' # Pointer
          if isdigit(sym.current[0])
              # FIXME: P6 = Function pointer, others who knows..
              if (sym.current.get_inc! == '6')
                  call_conv   = StringPtr.new
                  exported    = StringPtr.new
                  sub_ct      = DataType.new
                  saved_stack = sym.stack.dup

                  throw :done unless cc=get_calling_convention(
                    sym.current.get_inc!, sym.flags & ~UNDNAME_NO_ALLOCATION_LANGUAGE
                  )
                  call_conv, exported = cc

                  throw :done unless demangle_datatype(sym, sub_ct, pmt_ref, false)
                  throw :done unless args = get_args(sym, pmt_ref, true, '(', ')')
                  sym.stack = saved_stack

                  ct.left  = sprintf("%s%s (%s*", sub_ct.left, sub_ct.right, call_conv)
                  ct.right = sprintf(")%s", args)
              else
                throw :done
              end
          else
            throw :done unless get_modified_type(ct, sym, pmt_ref, 'P', in_args)
          end

      when 'W'
          if (sym.current[0] == '4')
              sym.current.inc!
              throw :done unless enum_name = get_class_name(sym)
              if sym.flags & UNDNAME_NO_COMPLEX_TYPE != 0
                  ct.left = enum_name
              else
                  ct.left = sprintf("enum %s", enum_name)
              end
          else
            throw :done
          end

      when /\d/
          # Referring back to previously parsed type
          # left and right are pushed as two separate strings
          ct.left  = pmt_ref[dt.to_i*2]
          ct.right = pmt_ref[dt.to_i*2 + 1]
          throw :done unless ct.left
          add_pmt = false

      when '$'
          case sym.current.get_inc!
          when '0'
              throw :done unless ct.left = get_number(sym)
          when 'D'
              throw :done unless ptr = get_number(sym)
              ct.left = sprintf("`template-parameter%s'", ptr)
          when 'F'
              throw :done unless p1 = get_number(sym)
              throw :done unless p2 = get_number(sym)
              ct.left = sprintf("{%s,%s}", p1, p2)
          when 'G'
              throw :done unless p1 = get_number(sym)
              throw :done unless p2 = get_number(sym)
              throw :done unless p3 = get_number(sym)
              ct.left = sprintf("{%s,%s,%s}", p1, p2, p3)
          when 'Q'
              throw :done unless ptr = get_number(sym)
              ct.left = sprintf("`non-type-template-parameter%s'", ptr)
          when '$'
              if (sym.current[0] == 'C')
                ptr       = ''
                ptr_modif = ''
                sym.current.inc!
                throw :done unless get_modifier(sym, ptr, ptr_modif)
                ptr       = nil if ptr.empty?
                ptr_modif = nil if ptr_modif.empty?

                throw :done unless demangle_datatype(sym, ct, pmt_ref, in_args)
                ct.left = sprintf("%s %s", ct.left, ptr)
              end
          end # case
      else
        err("Unknown type %c\n", dt)
      end # case dt=...

      if (add_pmt && pmt_ref && in_args)
        # left and right are pushed as two separate strings
        pmt_ref << (ct.left  || "")
        pmt_ref << (ct.right || "")
      end # if

    end # catch :done

    return ct.left != nil
  end # def demangle_datatype

  def get_modified_type(ct, sym, pmt_ref, modif, in_args)
    ptr_modif = ''

    if sym.current[0] == 'E'
      ptr_modif = " __ptr64"
      sym.current.inc!
    end

    str_modif =
      case modif
      when 'A'; sprintf(" &%s", ptr_modif)
      when 'B'; sprintf(" &%s volatile", ptr_modif)
      when 'P'; sprintf(" *%s", ptr_modif)
      when 'Q'; sprintf(" *%s const", ptr_modif)
      when 'R'; sprintf(" *%s volatile", ptr_modif)
      when 'S'; sprintf(" *%s const volatile", ptr_modif)
      when '?'; ""
      else
        return false
      end

    modifier = ''
    if get_modifier(sym, modifier, ptr_modif)
      modifier  = nil if modifier.empty?
      ptr_modif = nil if ptr_modif.empty?

      saved_stack = sym.stack.dup
      sub_ct = DataType.new

      # multidimensional arrays
      if (sym.current[0] == 'Y')
        sym.current.inc!
        return false unless n1 = get_number(sym)
        num = n1.to_i

        if (str_modif[0] == ' ' && !modifier)
          str_modif = str_modif[1..-1]
        end

        if (modifier)
          str_modif = sprintf(" (%s%s)", modifier, str_modif)
          modifier = nil
        else
          str_modif = sprintf(" (%s)", str_modif)
        end

        num.times do
          str_modif = sprintf("%s[%s]", str_modif, get_number(sym))
        end
      end

      # Recurse to get the referred-to type
      return false unless demangle_datatype(sym, sub_ct, pmt_ref, false)

      if modifier
        ct.left = sprintf("%s %s%s", sub_ct.left, modifier, str_modif)
      else
          # don't insert a space between duplicate '*'
          if (!in_args && str_modif[0] && str_modif[1] == '*' && sub_ct.left[-1] == '*')
            str_modif = str_modif[1..-1]
          end
          ct.left = sprintf("%s%s", sub_ct.left, str_modif )
      end
      ct.right = sub_ct.right
      sym.stack = saved_stack
    end # if get_modifier
    true
  end # def get_modified_type

  # Parses the type modifier.
  # XXX ZZZ FIXME must check that ret & ptr_modif are not simple checked like
  # if(!ret) or if(!ptr_modif)
  def get_modifier(sym, ret, ptr_modif)
    raise "ret must be a String" unless ret.is_a?(String)
    raise "ptr_modif must be a String" unless ptr_modif.is_a?(String)

    if sym.current[0] == 'E'
      ptr_modif[0..-1] = "__ptr64"
      sym.current.inc!
    else
      ptr_modif[0..-1] = ''
    end

    case sym.current.get_inc!
    when 'A'; ret[0..-1] = '' # XXX original: *ret = NULL, may affect further checks
    when 'B'; ret[0..-1] = "const"
    when 'C'; ret[0..-1] = "volatile"
    when 'D'; ret[0..-1] = "const volatile"
    else
      return false
    end

    true
  end # def get_modifier

  SIMPLE_TYPES = {
    'C' => "signed char", 'D' => "char", 'E' => "unsigned char",
    'F' => "short", 'G' => "unsigned short", 'H' => "int",
    'I' => "unsigned int", 'J' => "long", 'K' => "unsigned long",
    'M' => "float", 'N' => "double", 'O' => "long double",
    'X' => "void", 'Z' => "..."
  }

  EXTENDED_TYPES = {
    'D' => "__int8",  'E' => "unsigned __int8",
    'F' => "__int16", 'G' => "unsigned __int16",
    'H' => "__int32", 'I' => "unsigned __int32",
    'J' => "__int64", 'K' => "unsigned __int64",
    'L' => "__int128",'M' => "unsigned __int128",
    'N' => "bool",    'W' => "wchar_t"
  }

  def get_simple_type c;   SIMPLE_TYPES[c];   end
  def get_extended_type c; EXTENDED_TYPES[c]; end

  # Parses class as a list of parent-classes, terminated by '@' and stores the
  # result in 'a' array. Each parent-classes, as well as the inner element
  # (either field/method name or class name), are represented in the mangled
  # name by a literal name ([a-zA-Z0-9_]+ terminated by '@') or a back reference
  # ([0-9]) or a name with template arguments ('?$' literal name followed by the
  # template argument list). The class name components appear in the reverse
  # order in the mangled name, e.g aaa@bbb@ccc@@ will be demangled to
  # ccc::bbb::aaa
  def get_class(sym)
    name = nil
    while sym.current[0] != '@'
        case sym.current[0]
        when "\0",'',nil; return false
        when /\d/;
          # numbered backreference
          name = sym.names[sym.current.get_inc!.to_i]
        when '?'
          case sym.current.inc_get!
          when '$'
            sym.current.inc!
            return false unless name = get_template_name(sym)
            sym.names << name
          when '?'
            saved_stack, saved_names = sym.stack.dup, sym.names.dup
            name = "`#{sym.result}'" if symbol_demangle(sym)
            sym.stack, sym.names = saved_stack, saved_names
          else
            return false unless name = get_number(sym)
            name = "`#{name}'"
          end # case
        else
          name = get_literal_string(sym)
        end # case
        return false unless name
        sym.stack << name
    end # while
    sym.current.inc!
    true
  end # def get_class

  # Gets the literal name from the current position in the mangled symbol to the
  # first '@' character. It pushes the parsed name to the symbol names stack and
  # returns a pointer to it or nil in when of an error.
  def get_literal_string(sym)
    ptr = sym.current.dup
    idx = sym.current.index(/[^A-Za-z0-9_$]/) || sym.current.strlen
    if sym.current[idx] == '@'
      sym.current += idx+1
      sym.names << ptr[0, sym.current - ptr - 1]
      return sym.names.last
    else
      err("Failed at '%c' in %s\n", sym.current[0..-1], idx)
      return nil
    end
  end # def get_literal_string

  # Does the final parsing and handling for a function or a method in a class.
  def handle_method(sym, cast_op)
    access = member_type = name = modifier = call_conv = exported = args_str = name = nil
    array_pmt = []
    ret = false
    ct_ret = DataType.new

    accmem = sym.current.get_inc!
    return unless accmem =~ /[A-Z]/

    if sym.flags & UNDNAME_NO_ACCESS_SPECIFIERS == 0
      case ((accmem.ord - 'A'.ord) / 8)
      when 0; access = "private: "
      when 1; access = "protected: "
      when 2; access = "public: "
      end
    end

    if sym.flags & UNDNAME_NO_MEMBER_TYPE == 0
      if accmem <= 'X'
        case ((accmem.ord - 'A'.ord) % 8)
        when 2,3; member_type = "static "
        when 4,5; member_type = "virtual "
        when 6,7; member_type = "virtual "; access = "[thunk]:#{access}"
        end
      end
    end

    name = get_class_string(sym, 0)

    if ((accmem.ord - 'A'.ord) % 8 == 6 || (accmem.ord - '8'.ord) % 8 == 7) # a thunk
      name = sprintf("%s`adjustor{%s}' ", name, get_number(sym))
    end

    if (accmem <= 'X')
      if (((accmem.ord - 'A'.ord) % 8) != 2 && ((accmem.ord - 'A'.ord) % 8) != 3)
        modifier = ''; ptr_modif = ''
        # Implicit 'this' pointer
        # If there is an implicit this pointer, const modifier follows
        return unless get_modifier(sym, modifier, ptr_modif)
        modifier  = nil if modifier.empty?
        ptr_modif = nil if ptr_modif.empty?
        if (modifier || ptr_modif)
          modifier = "#{modifier} #{ptr_modif}"
        end
      end
    end

    return unless cc=get_calling_convention(sym.current.get_inc!, sym.flags)
    call_conv, exported = cc

    # Return type, or @ if 'void'
    if (sym.current[0] == '@')
      ct_ret.left  = "void"
      ct_ret.right = nil
      sym.current.inc!
    else
      return unless demangle_datatype(sym, ct_ret, array_pmt, false)
    end

    if sym.flags & UNDNAME_NO_FUNCTION_RETURNS != 0
      ct_ret.left = ct_ret.right = nil
    end

    if cast_op
      name = [name, ct_ret.left, ct_ret.right].join
      ct_ret.left = ct_ret.right = nil
    end

    saved_stack = sym.stack.dup
    return unless args_str = get_args(sym, array_pmt, true, '(', ')')
    if sym.flags & UNDNAME_NAME_ONLY != 0
      args_str = modifier = nil
    end
    sym.stack = saved_stack

    # Note: '()' after 'Z' means 'throws', but we don't care here
    # Yet!!! FIXME

    sym.result = [
      access, member_type, ct_ret.left, (ct_ret.left && !ct_ret.right) ? " " :
      nil, call_conv, call_conv ? " " : nil, exported, name, args_str, modifier,
      ct_ret.right
    ].join

    true
  end # def handle_method

  # From an array collected by get_class in sym.stack, constructs the
  # corresponding string
  def get_class_string(sym, start)
    sym.stack[start..-1].reverse.join('::')
  end

  # Returns a static string corresponding to the calling convention described
  # by char 'ch'. Sets export to true iff the calling convention is exported.

  def get_calling_convention(ch, flags)
    call_conv = exported = nil

    unless ch
      err("Unknown calling convention NULL\n")
      return false
    end

    if (flags & (UNDNAME_NO_MS_KEYWORDS | UNDNAME_NO_ALLOCATION_LANGUAGE)) == 0
      if (flags & UNDNAME_NO_LEADING_UNDERSCORES) != 0
        exported = "dll_export " if (((ch.ord - 'A'.ord) % 2) == 1)
        case ch
        when 'A','B'; call_conv = "cdecl"
        when 'C','D'; call_conv = "pascal"
        when 'E','F'; call_conv = "thiscall"
        when 'G','H'; call_conv = "stdcall"
        when 'I','J'; call_conv = "fastcall"
        when 'K','L'; # nothing
        when 'M';     call_conv = "clrcall"
        else
          err("Unknown calling convention %c\n", ch)
          return false
        end
      else
        exported = "__dll_export " if (((ch.ord - 'A'.ord) % 2) == 1)
        case ch
        when 'A','B'; call_conv = "__cdecl"
        when 'C','D'; call_conv = "__pascal"
        when 'E','F'; call_conv = "__thiscall"
        when 'G','H'; call_conv = "__stdcall"
        when 'I','J'; call_conv = "__fastcall"
        when 'K','L'; # nothing
        when 'M';     call_conv = "__clrcall"
        else
          err("Unknown calling convention %c\n", ch)
          return false
        end
      end
    end

    [call_conv, exported]
  end # def get_calling_convention

  # Parses a list of function/method arguments, creates a string corresponding
  # to the arguments' list.

  def get_args(sym, pmt_ref, z_term, open_char, close_char)
    ct = DataType.new
    arg_collect = []
    args_str = last = nil

    # Now come the function arguments
    while sym.current[0]
      # Decode each data type and append it to the argument list
      if sym.current[0] == '@'
        sym.current.inc!
        break
      end
      return unless demangle_datatype(sym, ct, pmt_ref, true)

      # 'void' terminates an argument list in a function
      break if z_term && ct.left == "void"
      arg_collect << [ct.left, ct.right].join
      break if ct.left == "..."
    end

    # Functions are always terminated by 'Z'. If we made it this far and don't
    # find it, we have incorrectly identified a data type.

    return if z_term && sym.current.get_inc! != 'Z'

    if arg_collect.empty? || arg_collect == ['void']
      return [open_char, "void", close_char].join
    end

    args_str = arg_collect.join(', ')
    # "...>>" => "...> >"
    args_str << " " if close_char == '>' && args_str[-1] == '>'

    [open_char, args_str, close_char].join
  end # def get_args

#  Wrapper around get_class and get_class_string.
  def get_class_name sym
    saved_stack = sym.stack.dup
    s = nil

    if get_class(sym)
      s = get_class_string(sym, saved_stack.size) # ZZZ ???
    end
    sym.stack = saved_stack
    s
  end # def get_class_name

  # Parses a name with a template argument list and returns it as a string.
  # In a template argument list the back reference to the names table is
  # separately created. '0' points to the class component name with the
  # template arguments.  We use the same stack array to hold the names but
  # save/restore the stack state before/after parsing the template argument
  # list.
  def get_template_name sym
    name = args = nil
    saved_names = sym.names.dup
    saved_stack = sym.stack.dup
    array_pmt = []

    sym.names = []
    return unless name = get_literal_string(sym)
    name << args if args = get_args(sym, array_pmt, false, '<', '>')

    sym.names = saved_names
    sym.stack = saved_stack

    name
  end # def get_template_name

  def get_number sym
    ptr = nil
    sgn = false

    if (sym.current[0] == '?')
      sgn = true
      sym.current.inc!
    end

    case sym.current[0]
    when /[0-8]/
      ptr = "  "
      ptr[0] = '-' if sgn
      ptr[sgn ? 1 : 0] = (sym.current[0].ord + 1).chr
      sym.current.inc!
      ptr.strip!
    when '9'
      ptr = "   "
      ptr[0] = '-' if sgn
      ptr[sgn ? 1 : 0] = '1'
      ptr[sgn ? 2 : 1] = '0'
      sym.current.inc!
      ptr.strip!
    when /[A-P]/
      ret = 0
      while sym.current[0] =~ /[A-P]/
        ret *= 16
        ret += sym.current.get_inc!.ord - 'A'.ord
      end
      return nil unless sym.current[0] == '@'

      ptr = sprintf("%s%d", sgn ? "-" : "", ret)
      sym.current.inc!
    else
      return nil
    end

    ptr
  end # def get_number

  # Does the final parsing and handling for a name with templates

  def handle_template sym
    assert(sym.current[0] == '$')
    sym.current.inc!
    return false unless name = get_literal_string(sym)
    return false unless args = get_args(sym, nil, false, '<', '>')
    sym.result = [name, args].join
    true
  end # def handle_template

  # Does the final parsing and handling for a variable or a field in a class.

  def handle_data sym
    name = access = member_type = modifier = ptr_modif = nil
    ct = DataType.new
    ret = false

    # 0 private static
    # 1 protected static
    # 2 public static
    # 3 private non-static
    # 4 protected non-static
    # 5 public non-static
    # 6 ?? static
    # 7 ?? static

    if sym.flags & UNDNAME_NO_ACCESS_SPECIFIERS == 0
      # we only print the access for static members
      case sym.current[0]
      when '0'; access = "private: "
      when '1'; access = "protected: "
      when '2'; access = "public: "
      end
    end

    if sym.flags & UNDNAME_NO_MEMBER_TYPE == 0
      member_type = "static " if sym.current[0] =~ /[012]/
    end

    name = get_class_string(sym, 0)

    case sym.current.get_inc!
    when /[0-5]/
      saved_stack = sym.stack.dup
      modifier = ''; ptr_modif = ''
      pmt = []
      return unless demangle_datatype(sym, ct, pmt, false)
      return unless get_modifier(sym, modifier, ptr_modif)
      modifier = nil  if modifier.empty?
      ptr_modif = nil if ptr_modif.empty?

      if modifier && ptr_modif
        modifier += " " + ptr_modif
      elsif !modifier
        modifier = ptr_modif
      end
      sym.stack = saved_stack

    when '6','7' # compiler generated static
      ct.left = ct.right = nil
      modifier = ''; ptr_modif = ''
      return unless get_modifier(sym, modifier, ptr_modif)
      modifier = nil  if modifier.empty?
      ptr_modif = nil if ptr_modif.empty?

      if (sym.current[0] != '@')
        return unless cls = get_class_name(sym)
        ct.right = "{for `#{cls}'}"
      end
    when '8','9'
        modifier = ct.left = ct.right = nil
    else
      return
    end # case

    if (sym.flags & UNDNAME_NAME_ONLY != 0)
      ct.left = ct.right = modifier = nil
    end

    sym.result = [
      access, member_type, ct.left, modifier && ct.left ? " " : nil, modifier,
      modifier || ct.left ? " " : nil, name, ct.right
    ].join

    true
  end # def handle_data

end # class MSVC

######################################################################

if $0 == __FILE__
  $:.unshift("./lib")
  require 'unmangler/string_ptr'
  require 'awesome_print'
  require 'pp'

  def check src, want, flags = 0
    want = src if want == :bad

    u = Unmangler::MSVC.new
    got = nil
    begin
      got = u.unmangle(src, flags)
    rescue
      pp u
      raise
    end
    if got == want
      print ".".green
    else
      puts
      puts "[!] want: #{want.inspect.yellow}"
      puts "[!]  got: #{got.inspect.red}"
#      pp u
#      exit 1
    end
  end

  if ARGV.any?
    check ARGV[0], ARGV[1]
    exit
  end

  check "?h@@YAXH@Z", "void __cdecl h(int)"
  check "?AFXSetTopLevelFrame@@YAXPAVCFrameWnd@@@Z", "void __cdecl AFXSetTopLevelFrame(class CFrameWnd *)"
  check "??0_Lockit@std@@QAE@XZ", "public: __thiscall std::_Lockit::_Lockit(void)"

  check "?SetAt@CString@@QAEXHD@Z", "public: void __thiscall CString::SetAt(int, char)"
  check "?LoadFrame@CMDIFrameWndEx@@UAEHIKPAVCWnd@@PAUCCreateContext@@@Z",
    "public: virtual int __thiscall CMDIFrameWndEx::LoadFrame(unsigned int, unsigned long, class CWnd *, struct CCreateContext *)"

  check "??0DNameStatusNode@@AEAA@W4DNameStatus@@@Z",
    "private: __cdecl DNameStatusNode::DNameStatusNode(enum DNameStatus) __ptr64"

  check "?Add@?$CArray@VCSize@@V1@@@QAEHVCSize@@@Z",
    "public: int __thiscall CArray<class CSize, class CSize>::Add(class CSize)"

  check "??$_Char_traits_cat@U?$char_traits@D@std@@@std@@YA?AU_Secure_char_traits_tag@0@XZ",
    "struct std::_Secure_char_traits_tag __cdecl std::_Char_traits_cat<struct std::char_traits<char> >(void)"

  check "?dtor$0@?0???0CDockSite@@QEAA@XZ@4HA",
    "int `public: __cdecl CDockSite::CDockSite(void) __ptr64'::`1'::dtor$1"

  # bad examples
  check "?ProcessAndDestroyEdit", :bad
  check "?dtor$0@?0??Add@?$CArray@VXQATItem@XQAT@CMFCRibbonInfo@@V123@@@QEA", :bad

  puts
end
