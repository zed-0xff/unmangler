$: << File.expand_path("../lib", File.dirname(__FILE__))
require 'unmangler'

SAMPLES_DIR = File.expand_path("../samples", File.dirname(__FILE__))

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true

  config.before :suite do
    Dir[File.join(SAMPLES_DIR, "*.bz2")].each do |fname|
      unless File.exist?(fname.sub(/\.bz2/,''))
        puts "[.] unpacking #{fname} .."
        system("bunzip2", "-dk", fname)
      end
    end
  end

  config.backtrace_clean_patterns = [/\/rspec/]
end
