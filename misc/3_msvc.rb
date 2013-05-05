#!/usr/bin/env ruby
require 'yaml'

a = File.readlines "names1.txt"
b = File.readlines "names1.txt.msvc"

raise unless a.size == b.size

strings = {}

h = {}
a.each_with_index do |src,idx|
  src.strip!
  dst = b[idx].strip
  #next if src == dst
  src = (strings[src] ||= src)
  dst = (strings[dst] ||= dst)
  h[strings[src]] = strings[dst]
end

File.write "msvc.yaml", h.to_yaml
File.write "msvc.marshal", Marshal.dump(h)
