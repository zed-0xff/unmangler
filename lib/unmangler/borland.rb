#!/usr/bin/env ruby
require File.expand_path("base", File.dirname(__FILE__))

# ported from Embarcadero RAD Studio XE3
# $(BDS)\source\cpprtl\Source\misc\unmangle.c
#
# most of the comments are from unmangle.c

module Unmangler; end

class Unmangler::Borland < Unmangler::Base
  attr_accessor :kind

  UM_UNKNOWN       = 0x00000000

  UM_FUNCTION      = 0x00000001
  UM_CONSTRUCTOR   = 0x00000002
  UM_DESTRUCTOR    = 0x00000003
  UM_OPERATOR      = 0x00000004
  UM_CONVERSION    = 0x00000005
  UM_DATA          = 0x00000006
  UM_THUNK         = 0x00000007
  UM_TPDSC         = 0x00000008
  UM_VTABLE        = 0x00000009
  UM_VRDF_THUNK    = 0x0000000a
  UM_DYN_THUNK     = 0x0000000b

  UM_KINDMASK      = 0x000000ff

  # Modifier (is it a member, template?).

  UM_QUALIFIED     = 0x00000100
  UM_TEMPLATE      = 0x00000200
  UM_VIRDEF_FLAG   = 0x00000400
  UM_FRIEND_LIST   = 0x00000800
  UM_CTCH_HNDL_TBL = 0x00001000
  UM_OBJ_DEST_TBL  = 0x00002000
  UM_THROW_LIST    = 0x00004000
  UM_EXC_CTXT_TBL  = 0x00008000
  UM_LINKER_PROC   = 0x00010000
  UM_SPECMASK      = 0x0001fc00

  UM_MODMASK       = 0x00ffff00

  # Some @kind of error occurred.

  UM_BUFOVRFLW     = 0x01000000
  UM_HASHTRUNC     = 0x02000000
  UM_ERROR         = 0x04000000

  UM_ERRMASK       = 0x7f000000

  # This symbol is not a mangled name.

  UM_NOT_MANGLED   = 0x80000000

  MAXBUFFLEN = 8192 # maximum output length

  # New mangle scheme lengths:
  #   len == 254 ==> old hash
  #   len == 253 ==> new MD5 hash
  #   len < 253  ==> unhashed

  QUALIFIER = '@'
  ARGLIST   = '$'
  TMPLCODE  = '%'

  def input
#    if @srcindx >= @hashstart
#      raise 'UM_HASHTRUNC'
#    else
      c = @source[0]
      #c == "\x00" ? 0 : c
#    end
  end

  def advance
    @source.inc!
    input
  end

  def copy_char c
    #puts "[d] copy_char #{c.inspect} from #{caller[0]}"
    @target[0] = (c == 0 ? "\x00" : c)
    @target.inc!
  end

  def copy_string s, len=0
    if len == 0
      @target << s
    else
      @target << s[0,len]
    end
  end

  alias :append :copy_string

  # copy all remaining input until input end or any of term_chars is met
  def copy_until *term_chars
    term =
      case term_chars.size
        when 0; raise "no term_chars"
        when 1; term_chars.first
        else
          Regexp.new( "[" + term_chars.map{ |c| Regexp::escape(c) }.join + "]" )
      end
    len = @source.index(term) || @source[0..-1].size
    @target << @source[0,len]
    @source += len
  end

  def strchr haystack, needle
    if idx = haystack.index(needle)
      StringPtr.new(haystack, idx)
    else
      nil
    end
  end

  OPS = {
    "add" => "+",  "adr" => "&",  "and" => "&",  "asg" => "=",  "land"=> "&&",
    "lor" => "||", "call"=> "()", "cmp" => "~",  "fnc" => "()", "dec" => "--",
    "div" => "/",  "eql" => "==", "geq" => ">=", "gtr" => ">",  "inc" => "++",
    "ind" => "*",  "leq" => "<=", "lsh" => "<<", "lss" => "<",  "mod" => "%",
    "mul" => "*",  "neq" => "!=", "new" => "new","not" => "!",  "or"  => "|",
    "rand"=> "&=", "rdiv"=> "/=", "rlsh"=> "<<=","rmin"=> "-=", "rmod"=> "%=",
    "rmul"=> "*=", "ror" => "|=", "rplu"=> "+=", "rrsh"=> ">>=","rsh" => ">>",
    "rxor"=> "^=", "subs"=> "[]", "sub" => "-",  "xor" => "^",  "arow"=> "->",
    "nwa" => "new[]", "dele"=> "delete", "dla" => "delete[]",
    # not in unmangle.c, but from IDA
    "cctr" => "`class constructor`", "cdtr" => "`class destructor`"
  }

  def copy_op src
    copy_string(OPS[src] || "?#{src}?")
  end

  def copy_return_type(start, callconv, regconv, process_return)
    start = start.dup if start.is_a?(StringPtr)

    ret_len = 0
    # Process the return type of a function, and shuffle the output
    #   text around so it looks like the return type came first.
    ret_type = @target.dup

    unless [0,nil,false].include?(process_return)
      copy_type(@target, 0)
      copy_char(' ')
    end

    copy_string(callconv) if callconv
    copy_string(regconv) if regconv

    ret_len = @target - ret_type

    # Set up the return type to have a space after it.

    # "foo((*)(float, int)double "

    buff = ret_type[0, ret_len]
    start[ret_len, ret_type-start] = start[0, ret_type-start]
    start[0, ret_len] = buff[0, ret_len]

    # "foo(double (*)(float, int)"

    # If we are inserting this return type at the very beginning of a
    #   string, it means the location of all the qualifier names is
    #   about to move.

    if @adjust_quals
      @namebase += ret_len if @namebase
      @qualend  += ret_len if @qualend
      @prevqual += ret_len if @prevqual
      @base_name+= ret_len if @base_name
      @base_end += ret_len if @base_end
    end
  end # def copy_return_type

  def copy_type(start, arglvl)
    start = start.dup if start.is_a?(StringPtr)

    tname = buff  = nil
    c             = input()
    is_const      = false
    is_volatile   = false
    is_signed     = false
    is_unsigned   = false
    savedsavechar = nil

    arglvl =
      case arglvl
      when 0, nil, false; false
      else true
      end

    maxloop = 101
    loop do
      assert((maxloop-=1) > 0)
      case c
      when 'u'; is_unsigned = true
      when 'z'; is_signed   = true
      when 'x'; is_const    = true
      when 'w'; is_volatile = true
      when 'y'
        # 'y' for closure is followed by 'f' or 'n'
        c = advance()
        assert(c == 'f' || c == 'n')
        copy_string("__closure")
      else
        break
      end

      c = advance()
    end # loop

    if isdigit(c)    # enum or class name
      i = 0

      begin      # compute length
          i = i*10 + c.to_i
          c = advance()
      end while isdigit(c)

      # Output whether this class name was const or volatile.

      # These were already printed (see  [BCB-265738])
      #if 0
      #  if (is_const) copy_string("const ")
      #  if (is_volatile) copy_string("volatile ")
      #endif

      # ZZZ
      s0 = @source.string.dup
      @source[i] = "\x00"
      @source.trim!
      copy_name(0)
      @source.string = s0
      @target.trim!
      return
    end # if isdigit(c)

    @savechar = c
    tname = nil

    if c == 'M' # member pointer
      name = @target.dup
      # We call 'copy_type' because it knows how to extract
      # length-prefixed names.
      advance()
      copy_type(@target, 0)
      len = @target - name
      #len = MAXBUFFLEN - 1 if (len > MAXBUFFLEN - 1)
      buff = name[0,len]
      @target = name
    end

    case c
    when 'v'; tname = "void"
    when 'c'; tname = "char"
    when 'b'; tname = "wchar_t"
    when 's'; tname = "short"
    when 'i'; tname = "int"
    when 'l'; tname = "long"
    when 'f'; tname = "float"
    when 'd'; tname = "double"
    when 'g'; tname = "long double"
    when 'j'; tname = "long long"
    when 'o'; tname = "bool"
    when 'e'; tname = "..."

    when 'C'      # C++ wide char
      c = advance()
      if c == 's'
        tname = "char16_t"
      elsif c == 'i'
        tname = "char32_t"
      else
        raise "Unknown wide char type: 'C#{c}'"
      end

    when 'M','r','h','p' # member pointer, reference, rvalue reference, pointer
      if (@savechar == 'M')
        case c = input()  # [BTS-??????]
        when 'x'; is_const = true; c = advance()    # [BCB-272500]
        when 'w'; is_volatile = true; c = advance()
        end
      else
        c = advance()
      end

      if (c == 'q')    # function pointer
        copy_char('(')

        if (@savechar == 'M')
          copy_string(buff)
          append "::"
        end

        append "*)"

        @savechar = c
      end

      savedsavechar = @savechar;    # [BTS-263572]
      copy_type(start, 0)
      @savechar = savedsavechar

      case @savechar
      when 'r'; copy_char('&')
      when 'h'; append('&&')
      when 'p'; append(' *')
      when 'M'
        assert(buff)
        copy_char(' ')
        copy_string(buff)
        append '::*'
      end

    when 'a'      # array
      dims = ''

      begin
        c = advance()
        dims << '['
        c = advance() if (c == '0') # 0 size means unspecified
        while (c != '$')  # collect size, up to '$'
          dims << c
          c = advance()
        end
        assert(c == '$')
        c = advance()
        dims << ']'
      end while (c == 'a')  # collect all dimensions

      copy_type(@target, 0)
      copy_string(dims)

    when 'q'      # function
      callconv = regconv = hasret = save_adjqual = nil

      # We want the return type first, but find it last. So we emit
      # all but the return type, get the return type, then shuffle
      # to get them in the right place.

      loop do
        break if (advance() != 'q')

        case advance()
        when 'c'; callconv = "__cdecl "
        when 'p'; callconv = "__pascal "
        when 'r'; callconv = "__fastcall "
        when 'f'; callconv = "__fortran "
        when 's'; callconv = "__stdcall "
        when 'y'; callconv = "__syscall "
        when 'i'; callconv = "__interrupt "
        when 'g'; regconv = "__saveregs "
        end
      end

      save_adjqual = @adjust_quals
      @adjust_quals = false

      copy_char('(')
      copy_args('$', 0)
      copy_char(')')

      @adjust_quals = save_adjqual

      hasret = input() == '$'
      advance() if hasret

      if (hasret || callconv || regconv)
        copy_return_type(start, callconv, regconv, hasret)
      end

    when ARGLIST      # template arg list
      # break
    when TMPLCODE      # template reference
      # break

    else
      raise "Unknown type: #{c.inspect}"
    end # case

    if (tname)
      copy_string("const ")    if is_const
      copy_string("volatile ") if is_volatile
      copy_string("signed ")   if is_signed
      copy_string("unsigned ") if is_unsigned
      copy_string(tname)       if (!arglvl || @savechar != 'v')
      advance()
    else
      copy_string(" const")    if is_const
      copy_string(" volatile") if is_volatile
    end
  end # def copy_type

  def copy_delphi4args(_end, tmplargs)
    first = true
    _begin = start = nil
    termchar = nil

    tmplargs =
      case tmplargs
      when 0, nil, false; false
      else true
      end

    c = input()
    while (c && c != _end)
      if first
        first = false
      else
        append ', '
      end

      _begin = @source.dup
      start  = @target.dup

      advance()    # skip the @kind character

      # loop is for fallthrough emulation
      loop do
        case c
        when 't'
          copy_type(@target, ! tmplargs)
          break

        when 'T'
          copy_string("<type ")
          termchar = '>'
          c = 'i'; redo # fall through

        when 'i'
          if _begin[0,5] == '4bool'
            copy_string( input() == '0' ? "false" : "true" )
            advance()
            break
          else
            # XXX ZZZ fall through, but not sure that its intended behaviour
            # in original code
            c = 'j'; redo
          end

        when 'j','g','e'
          copy_type(@target, ! tmplargs)
          @target = start.dup
          assert(input() == '$'); advance()
          copy_until('$', TMPLCODE)
          copy_char(termchar) if termchar
          break

        when 'm'
          copy_type(@target, ! tmplargs)
          @target = start.dup
          assert(input() == '$'); advance()

          copy_until('$')
          append '::*'
          copy_until('$', TMPLCODE)
          break

        else
          raise "Unknown template arg @kind"
        end # case
      end # loop

      c = input()
      if (c != _end)
        assert(c == '$')
        c = advance()
      end
    end # while c && c != _end
  end

  # The mangler, when mangling argument types, will create
  # backreferences if the type has already been seen. These take the
  # form t?, where ? can be either 0-9, or a-z.
  PEntry = Struct.new :start, :len

  def copy_args(_end, tmplargs)
    c = input()
    first = true
    _begin = start = nil
    scanned = false
    param_table = []

    tmplargs =
      case tmplargs
      when 0, nil, false; false
      else true
      end

    while c && ![0, "\0", _end].include?(c)
      if first
        first = false
      else
        append ', '
      end

      _begin   = @source.dup
      start    = @target.dup

      param_table << PEntry.new( @target.dup )
      scanned = false

      while c == 'x' || c == 'w'
        # Decode 'const'/'volatile' modifiers [BCB-265738]
        case c
        when 'x'; copy_string("const ")
        when 'w'; copy_string("volatile ")
        end
        scanned = true
        c = advance()
      end

      if scanned && c != 't'
        @source = _begin.dup
      end

      if c == 't'
        c = advance()
        ptindex = c.to_i(36) - 1
        assert(param_table[ptindex].start)
        assert(param_table[ptindex].len > 0)
        copy_string param_table[ptindex].start[0, param_table[ptindex].len]
        advance()
      else
        copy_type(@target, ! tmplargs)
      end

      param_table.last.len = @target - param_table.last.start

      c = input()

      if (tmplargs && c == '$') # non-type template argument
        termchar = nil
        @target = start.dup
        c = advance()
        advance()
        loop do # loop is for fall through emulation
          case c
          when 'T'
            copy_string("<type ")
            termchar = '>'
            c = 'i'; redo # fall through

          when 'i'
            if _begin[0,5] == "4bool"
              copy_string( input() == '0' ? "false" : "true" )
              advance()
              break
            end
            c = 'j'; redo # fall through

          when 'j','g','e'
            copy_until('$')
            copy_char(termchar) if termchar
            break

          when 'm'
            copy_until('$')
            append '::*'
            copy_until('$')
            break

          else
            raise "Unknown template arg @kind"
          end # case
        end # loop

        assert(input() == '$')
        c = advance()
      end # if
    end # while (c && c != _end)
  end # def copy_args

  # parse template name and arguments according to the grammar:
  #  tmpl_args:
  #      % generic_name args %
  #  args:
  #      $ new_args
  #      bcb3_args
  def copy_tmpl_args
    c = input()
    save_setqual = nil
    isDelphi4name = (c == 'S' || c == 'D') && (@source =~ /\A(Set|DynamicArray|SmallString|DelphiInterface)\$/)

    # Output the base name of the template. We use 'copy_name' instead of
    # 'copy_until', since this could be a template constructor name, f.ex.

    copy_name(1)
    assert(input() == ARGLIST)
    advance()

    # using @target[-1] will be ambiguous for ruby's string[-1] - last char of string
    copy_char(' ') if (@target-1)[0] == '<'
    copy_char('<')

    # Copy the template arguments over.  Also, save the
    # '@set_qual' variable, since we don't want to mix up the
    # status of the currently known qualifier name with a
    # name from a template argument, for example.

    save_setqual = @set_qual
    @set_qual = false

    if isDelphi4name
      copy_delphi4args(TMPLCODE, 1)
    else
      copy_args(TMPLCODE, 1)
    end

    @set_qual = save_setqual

    # using @target[-1] will be ambiguous for ruby's string[-1] - last char of string
    copy_char(' ') if (@target-1)[0] == '>'
    copy_char('>')

    assert(input() == TMPLCODE)
    advance()
  end

  def copy_name tmplname
    start = save_setqual = nil
    c = input()

    tmplname =
      case tmplname
      when 0, nil, false; false
      else true
      end

    # Start outputting the qualifier names and the base name.

    while true
      if @set_qual
        @base_name = @target.dup
      end

      # Examine the string to see what this is.  Either it's a
      # qualifier name, a member name, a function name, a template
      # name, or a special name. We wouldn't be here if this were a
      # regular name.

      if isdigit(c)
        # If there's a number at the beginning of a name, it
        #   could only be a vtable symbol flag.

        flags = c[0].ord - '0'.ord + 1

        @vtbl_flags << "huge"     if( flags & 1 != 0 )
        @vtbl_flags << "fastthis" if( flags & 2 != 0 )
        @vtbl_flags << "rtti"     if( flags & 4 != 0 )

        @kind = (@kind & ~UM_KINDMASK) | UM_VTABLE

        c = advance()
        assert(c == 0 || c == '$')
      end

      case c
        when '#'    # special symbol used for cond syms
          c = advance()
          if c == '$'
            assert(advance() == 'c')
            assert(advance() == 'f')
            assert(advance() == '$')
            assert(advance() == '@')

            copy_string("__vdflg__ ")
            advance()
            copy_name(0)

            @kind |= UM_VIRDEF_FLAG
          end
          return

        when QUALIFIER    # virdef flag or linker proc
            advance()
            copy_string("__linkproc__ ")
            copy_name(0)
            @kind |= UM_LINKER_PROC
            return

        when TMPLCODE    # template name
          advance()
          copy_tmpl_args()

          if (input() != QUALIFIER)
            @kind |= UM_TEMPLATE
          end

        when ARGLIST    # special name, or arglist
          return if tmplname

          c = advance()
          if c == 'x'
            c = advance()
            if c == 'p' || c == 't'
              assert(advance() == ARGLIST)
              advance()
              copy_string("__tpdsc__ ")
              copy_type(@target, 0)
              @kind = (@kind & ~UM_KINDMASK) | UM_TPDSC
              return
            else
              raise "What happened?"
            end
          end # if c == 'x'

          if c == 'b'
            c = advance()
            start = @source.dup

            if (c == 'c' || c == 'd') && advance() == 't' && advance() == 'r'
                assert(advance() == ARGLIST)

                # The actual outputting of the name will happen
                #   outside of this function, to be sure that we
                #   don't include any special name characters.

                if (c == 'c')
                  @kind = (@kind & ~UM_KINDMASK) | UM_CONSTRUCTOR
                else
                  @kind = (@kind & ~UM_KINDMASK) | UM_DESTRUCTOR
                end
            else
              @source = start.dup
              copy_string("operator ")
              start = @target.dup
              copy_until(ARGLIST)
              @target = start      # no dup() here intentionally
              # copy_op now will overwrite already copied encoded operator name
              # i.e. "subs" => "[]"
              copy_op start[0..-1]
              # trim string if decoded operator name was shorter than encoded
              @target[0..-1] = ''
              @kind = (@kind & ~UM_KINDMASK) | UM_OPERATOR
            end

          elsif (c == 'o')
            advance()
            copy_string("operator ")
            save_setqual = @set_qual
            @set_qual = false
            copy_type(@target, 0)
            @set_qual = save_setqual
            assert(input() == ARGLIST)
            @kind = (@kind & ~UM_KINDMASK) | UM_CONVERSION

          elsif (c == 'v' || c == 'd')
            tkind = c
            c = advance()
            if (tkind == 'v' && c == 's')
              c = advance()
              assert(c == 'f' || c == 'n')
              advance()
              copy_string("__vdthk__")
              @kind = (@kind & ~UM_KINDMASK) | UM_VRDF_THUNK
            elsif (c == 'c')
              c = advance()
              assert(isdigit(c))
              c = advance()
              assert(c == '$')
              c = advance()

              copy_string("__thunk__ [")
              @kind = (@kind & ~UM_KINDMASK) |
              (tkind == 'v' ? UM_THUNK : UM_DYN_THUNK)

              copy_char(c)
              copy_char(',')

              while ((c = advance()) != '$'); copy_char(c); end
              copy_char(',')
              while ((c = advance()) != '$'); copy_char(c); end
              copy_char(',')
              while ((c = advance()) != '$'); copy_char(c); end
              copy_char(']')

              advance()  # skip last '$'
              return
            end
          else
            raise "Unknown special name"
          end

        when '_'
          start = @source.dup

          if advance() == '$'
            c = advance()

            # At the moment there are five @kind of special names:
            #   frndl FL friend list
            #   chtbl CH catch handler table
            #   odtbl DC object destructor table
            #   thrwl TL throw list
            #   ectbl ETC exception context table

            append '__'

            case @source[0,2]
              when 'FL'
                copy_string("frndl")
                @kind |= UM_FRIEND_LIST

              when 'CH'
                copy_string("chtbl")
                @kind |= UM_CTCH_HNDL_TBL

              when 'DC'
                copy_string("odtbl")
                @kind |= UM_OBJ_DEST_TBL

              when 'TL'
                copy_string("thrwl")
                @kind |= UM_THROW_LIST

              when 'EC'
                copy_string("ectbl")
                @kind |= UM_EXC_CTXT_TBL
            end

            append '__ '

            while (c >= 'A' && c <= 'Z'); c = advance(); end

            assert(c == '$')
            assert(advance() == '@')
            advance()

            copy_name(0)

            return
          end # if advance() == '$'

          @source = start.dup
          copy_until(QUALIFIER, ARGLIST)

        else
          # default case
          copy_until(QUALIFIER, ARGLIST)
      end # case c

      # If we're processing a template name, then '$' is allowed to
      #   end the name.

      c = input()

      assert(c == nil || c == QUALIFIER || c == ARGLIST)

      if c == QUALIFIER
        c = advance()

        if @set_qual
          @prevqual = @qualend && @qualend.dup
          @qualend  = @target.dup
        end

        append '::'

        if (c == 0)
          @kind = (@kind & ~UM_KINDMASK) | UM_VTABLE
        end
      else
        break
      end
    end # while true
  end # def copy_name

  # umKind unmangle(src, dest, maxlen, qualP, baseP, doArgs)
  #
  #   doArgs
  #     if this argument is non-0 (aka TRUE), it means that when
  #     unmangling a function name, its arguments should also be
  #     unmangled as part of the output name.  Otherwise, only the name
  #     will be unmangled, and not the arguments.

  def unmangle src, args = {}
    # all Borland mangled names start with '@' character.
    return src if !src || src.empty? || src[0] != '@'

    # check for Microsoft compatible fastcall names, which are of the form:
    # @funcName@<one or more digits indicating size of all parameters>
    return src if src =~ /\A@.*@\d+\Z/

    # unmangle args? defaulting to true
    doArgs = args.fetch(:args, true)

    @vtbl_flags = []
    @kind = 0
    @source_string = ''
    @source = StringPtr.new(@source_string)
    @result = ''
    @target = StringPtr.new(@result)

    #return UM_ERROR if src.size > 254
    @hashstart =
      case src.size
      when 254 # old hash for bcc version 0x600 and earlier
        250
      when 253 # new hash for bcc version 0x610 and later
        231
      else
        MAXBUFFLEN
      end

    @savechar = 0

    src = src[1..-1] # skip initial '@'

# ZZZ XXX not sure if it's needed now
#    if src[/[a-z]/]
#      # contains lowercase letters => not Pascal
#      # b/c Pascal names can not contain lowercase letters
#    else
#      # Pascal, convert uppercase Pascal names to lowercase
#      src.downcase!
#    end

    # This is at LEAST a member name, if not a fully mangled template
    # or function name. So, begin outputting the subnames. We set up
    # the pointers in globals so that we don't have to pass
    # everything around all the time.

    @kind      = UM_UNKNOWN
    @source_string = src
    @source    = StringPtr.new(@source_string)
    @prevqual  = @qualend = @base_name = @base_end = nil
    @set_qual  = true

    # Start outputting the qualifier names and the base name.

    @namebase = @target.dup

    copy_name(0)
    @set_qual = false
    @base_end = @target.dup

    if (@kind & UM_KINDMASK) == UM_TPDSC || (@kind & UM_SPECMASK) != 0
      p = strchr(@namebase, ' ')
      assert(p)
      @namebase = p + 1
    end

    if [UM_CONSTRUCTOR,UM_DESTRUCTOR].include?( @kind & UM_KINDMASK )
      copy_char('~') if @kind & UM_KINDMASK == UM_DESTRUCTOR

      if @qualend
        start = @prevqual ? (@prevqual+2) : @namebase.dup
        len = @qualend - start
        copy_string(start, len)
      else
        # It's a bcc-created static constructor??
        # give it a name.
        copy_string("unknown")
      end
    end

    # If there's a function argument list, copy it over in expanded
    #   form.

    if input() == ARGLIST && doArgs # function args
      c = advance()
      assert(c == 'q' || c == 'x' || c == 'w')

      # Output the function parameters, and return type in the case
      #   of template function specializations.

      @set_qual = false
      @adjust_quals = true

      copy_type(@namebase, 0)

      if ((@kind & UM_KINDMASK) == UM_UNKNOWN)
        @kind |= UM_FUNCTION
      end

    elsif ((@kind & UM_KINDMASK) == UM_UNKNOWN)
      @kind |= UM_DATA
    elsif @vtbl_flags.any?
      copy_string(" (" + @vtbl_flags.join(", ") + ")")
    end

    # Put some finishing touches on the @kind of this entity.

    if (@qualend)
      @kind |= UM_QUALIFIED
    end

    # trim unwanted result tail, if any
    @target[0..-1] = ''

    # If the user wanted the qualifier and base name saved, then do it now.

    # TODO
#    if (@kind & UM_ERRMASK) == 0
#      if @qualend
#        len = @qualend - @namebase
#        @qualP = @namebase[0, len]
#      end
#
#      if @base_name
#        len = @base_end - @base_name
#        @baseP = @base_name[0, len]
#      end
#    end

    # move '__fastcall' to start of the string if its found in middle of string
    pos = @result.index(" __fastcall ")
    if pos && pos != 0
      @result = "__fastcall " + @result.sub("__fastcall ", "")
    end

    # sometimes const args are marked "const const",
    # original tdump.exe tool also have this bug
    @result.gsub! "const const ", "const "

    # doArgs implicitly includes calling convention, but '__tpdsc__' is always
    # returned by original code, so strip it here if doArgs == false
    unless doArgs
      @result.sub! /\A__tpdsc__ /,''
    end

    # copy IDA syntax for class ctor/dtor:
    #   was: Classes::TThread::operator `class destructor`()
    #   now: Classes::TThread::`class destructor`()
    @result.sub! '::operator `class', '::`class'

    @result
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
end # class Unmangler

###################################################################

if $0 == __FILE__
  $:.unshift("./lib")
  require 'unmangler/string_ptr'
  require 'awesome_print'
  require 'pp'

  def check src, want, args = {}
    u = Unmangler::Borland.new
    got = nil
    begin
      got = u.unmangle(src, args)
    rescue
      pp u
      raise
    end
    if got == want
      print ".".green
    else
      puts
      puts "[!]  src: #{src.inspect.gray}"
      puts "[!] want: #{want.inspect.yellow}"
      puts "[!]  got: #{got.inspect.red}"
      puts
      pp u
      exit 1
    end
  end

  if ARGV.any?
    check ARGV[0], ARGV[1]
    exit
  end

  check "@afunc$qxzcupi",   "afunc(const signed char, int *)"
  check "@foo$qpqfi$d",     "foo(double (*)(float, int))"
  check "@myclass@func$qil","myclass::func(int, long)"

  check "@Sysinit@@InitExe$qqrpv",
    "__fastcall Sysinit::__linkproc__ InitExe(void *)"

  check "@Forms@TApplication@SetTitle$qqrx17System@AnsiString",
    "__fastcall Forms::TApplication::SetTitle(const System::AnsiString)"

  check "@Forms@TApplication@CreateForm$qqrp17System@TMetaClasspv",
    "__fastcall Forms::TApplication::CreateForm(System::TMetaClass *, void *)"

  check "@System@@LStrCatN$qqrv", "__fastcall System::__linkproc__ LStrCatN()"

  check "@System@DynArraySetLength$qqrrpvpvipi",
    "__fastcall System::DynArraySetLength(void *&, void *, int, int *)"

  check "@System@Variant@PutElement$qqrrx14System@Variantxixi",
    "__fastcall System::Variant::PutElement(System::Variant&, const int, const int)"

  check "@Windows@HwndMSWheel$qqrruit1t1rit4",
    "__fastcall Windows::HwndMSWheel(unsigned int&, unsigned int&, unsigned int&, int&, int&)"

  # IDA uses '__int64' instead of 'long long'
  check "@Sysutils@TryStrToInt64$qqrx17System@AnsiStringrj",
    "__fastcall Sysutils::TryStrToInt64(const System::AnsiString, long long&)"

  check "@Sysutils@Supports$qqrpx14System@TObjectrx5_GUIDpv",
    "__fastcall Sysutils::Supports(System::TObject *, _GUID&, void *)"

  check "@std@%vector$51boost@archive@detail@basic_iarchive_impl@cobject_id69std@%allocator$51boost@archive@detail@basic_iarchive_impl@cobject_id%%@$bsubs$qui",
    "std::vector<boost::archive::detail::basic_iarchive_impl::cobject_id, std::allocator<boost::archive::detail::basic_iarchive_impl::cobject_id> >::operator [](unsigned int)"

  check "@Dbcommon@GetTableNameFromSQLEx$qqrx17System@WideString25Dbcommon@IDENTIFIEROption",
    "__fastcall Dbcommon::GetTableNameFromSQLEx(const System::WideString, Dbcommon::IDENTIFIEROption)"

  check "@$xt$p27System@%AnsiStringT$us$i0$%", "__tpdsc__ System::AnsiStringT<0> *"

  check "@Adomcore_4_3@TDomNamedNodeMap@$bctr$qqrpx21Adomcore_4_3@TDomNodepx13Classes@TListx54System@%Set$t25Adomcore_4_3@TDomNodeType$iuc$0$iuc$11%xo",
    "__fastcall Adomcore_4_3::TDomNamedNodeMap::TDomNamedNodeMap(Adomcore_4_3::TDomNode *, Classes::TList *, const System::Set<Adomcore_4_3::TDomNodeType, 0, 11>, const bool)"

  check '@ATL@%CComObjectRootEx$25ATL@CComSingleThreadModel%@$bctr$qv',
    "ATL::CComObjectRootEx<ATL::CComSingleThreadModel>::CComObjectRootEx<ATL::CComSingleThreadModel>()"

  check '@Classes@TThread@$bcdtr$qqrv',    '__fastcall Classes::TThread::`class destructor`()'
  check '@Timespan@TTimeSpan@$bcctr$qqrv', '__fastcall Timespan::TTimeSpan::`class constructor`()'

  ####################################
  # w/o args
  ####################################

  check "@Dbcommon@GetTableNameFromSQLEx$qqrx17System@WideString25Dbcommon@IDENTIFIEROption",
    "Dbcommon::GetTableNameFromSQLEx",
    :args => false

  check "@std@%vector$51boost@archive@detail@basic_iarchive_impl@cobject_id69std@%allocator$51boost@archive@detail@basic_iarchive_impl@cobject_id%%@$bsubs$qui",
    "std::vector<boost::archive::detail::basic_iarchive_impl::cobject_id, std::allocator<boost::archive::detail::basic_iarchive_impl::cobject_id> >::operator []",
    :args => false

  puts
end
