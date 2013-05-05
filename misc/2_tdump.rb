#!/usr/bin/env ruby
require 'open3'
require 'shellwords'
require 'yaml'

#TDUMP_PATH = "/mnt/windows/Program Files (x86)/Embarcadero/RAD Studio/10.0/bin/tdump.exe"
TDUMP_PATH = "./tdump.exe"

TEMPFILE = "ttt"

names = File.read("names1.txt").
  strip.
  split("\n").
  map(&:strip).
  keep_if{ |name| name[0] == '@' } # Borland mangled names start with '@'

bad_names = []

@h = {}

########################################

def process_chunk names
  puts "[.] chunk size = #{names.size}"
  File.write TEMPFILE, names.join("\n")
  cmd = Shellwords.shelljoin ["wine", TDUMP_PATH, "-q", "-um", TEMPFILE]
  r = `#{cmd}`
  if $?.success?
    a = r.strip.split("\n").map(&:strip).delete_if{ |line| line['Display of File'] }
    raise if a.size != names.size
    a.each_with_index do |unmangled, idx|
      raise if unmangled.empty?
      name = names[idx]
      #printf "[.] %3d: %-40s = %s\n", idx, name, unmangled
      @h[name] = unmangled
    end
  elsif names.size == 1
    # ignore single bad name
    puts "[-] ignoring #{names[0].inspect}"
  else
    # many names
    new_chunk_size = names.size/2
    process_chunk(names[0, new_chunk_size])
    process_chunk(names[new_chunk_size..-1])
  end
  return
  Open3.popen3("wine", TDUMP_PATH, "-q", "-um") do |i,o,e,t|
    i.puts names.join("\n")
    i.close

    s = o.gets
    raise unless s['Display of File']
    names.each_with_index do |name,idx|
      unmangled = o.gets.strip
      raise if unmangled.empty?
      #printf "[.] %3d: %-40s = %s\n", idx, name, unmangled
    end

    o.close
    e.close
  end
end

########################################

chunks = names.each_slice(1024).to_a

chunks.each_with_index do |chunk, idx|
  puts "[.] chunk ##{idx} of #{chunks.size}"
  process_chunk chunk
end

File.write "borland.yaml", @h.to_yaml
