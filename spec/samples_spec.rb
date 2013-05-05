require 'spec_helper'

def combined_samples
  @@combined_samples ||=
    begin
      msvc    = YAML::load_file(File.join(SAMPLES_DIR, "msvc.yaml"))
      borland = YAML::load_file(File.join(SAMPLES_DIR, "borland.yaml"))

      combined = {}
      (msvc.keys + borland.keys).uniq.each do |key|
        um = msvc[key]
        ub = borland[key]

        combined[key] =
          if um && um != key
            preprocess_msvc um
          elsif ub && ub != key
            preprocess_borland ub
          else
            # neither
            key
          end
      end
      combined
    end
end

describe Unmangler do
  if max_idx = ENV['LONG_RUN']
    max_idx = max_idx.to_i
    idx = 0
    combined_samples.each do |mangled, unmangled|
      idx += 1
      break if idx > max_idx
      it "should unmangle #{mangled}" do
        Unmangler.unmangle(mangled).should == unmangled
      end
    end
  else
    it "should unmangle" do
      combined_samples.each do |mangled, unmangled|
        actual = Unmangler.unmangle(mangled)
        actual.should eql(unmangled), [
          "mangled : #{mangled.white}",
          "expected: #{unmangled.green}",
          "actual  : #{actual.red}"
        ].join("\n")
      end
    end
  end
end
