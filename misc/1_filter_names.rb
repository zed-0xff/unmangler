#!/usr/bin/env ruby

# removes parial duplicates like '@ADODB@_12345' & '@ADODB@_12567'

if ARGV.empty?
  puts "gimme a fname"
  exit
end

prev_line = ''
File.read(ARGV.first).strip.split("\n").sort.each do |line|
  if line[0,2] == "__"
    # special SEH-related names like
    #   __unwindfunclet$...
    #   __ehhandler$...
    #   __catch$...
    next
  end

  # ???
  next if line[/<lambda\d>/]

  if line =~ /\A@(\w+)@_\d+\Z/
    name1 = $1
    if prev_line =~ /\A@(\w+)@_\d+\Z/
      name2 = $1
      next if name1 == name2
    end
  end
  puts line
  prev_line = line
end
