require 'yaml'
require 'awesome_print'

$: << File.expand_path("../lib", File.dirname(__FILE__))
require 'unmangler'

SAMPLES_DIR = File.expand_path("../samples", File.dirname(__FILE__))

def preprocess_msvc s
  s.gsub(',',', ')
end

def preprocess_borland s
    r = s.gsub('const const ','const ')

    # move '__fastcall' to start of the string if its found in middle of string
    pos = r.index(" __fastcall ")
    if pos && pos != 0
      r = "__fastcall " + r.sub("__fastcall ", "")
    end

    r
end

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true

  config.before(:suite) do
    Dir[File.join(SAMPLES_DIR, "*.bz2")].each do |fname|
      unless File.exist?(fname.sub(/\.bz2$/,''))
        puts "[.] unpacking #{fname} .."
        system("bunzip2", "-dk", fname)
      end
    end
  end

  config.backtrace_clean_patterns = [/\/rspec/]
end
