require 'spec_helper'

describe Unmangler::MSVC do
  if max_idx = ENV['LONG_RUN']
    max_idx = max_idx.to_i
    idx = 0
    YAML::load_file(File.join(SAMPLES_DIR, "msvc.yaml")).each do |mangled, unmangled|
      idx += 1
      break if idx > max_idx
      it "should unmangle #{mangled}" do
        unmangled = preprocess_msvc unmangled
        Unmangler::MSVC.unmangle(mangled).should == unmangled
      end
    end
  else
    it "should unmangle" do
      YAML::load_file(File.join(SAMPLES_DIR, "msvc.yaml")).each do |mangled, unmangled|
        unmangled = preprocess_msvc unmangled
        actual = Unmangler::MSVC.unmangle(mangled)
        actual.should eql(unmangled), [
          "mangled : #{mangled.white}",
          "expected: #{unmangled.green}",
          "actual  : #{actual.red}"
        ].join("\n")
      end
    end
  end
end
