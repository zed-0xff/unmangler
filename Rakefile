require "bundler/gem_tasks"
require 'rspec/core/rake_task'

desc "run specs"
RSpec::Core::RakeTask.new

task :default => :spec

desc "build readme"
task :readme do
  tpl = File.read('README.md.tpl')
  result = tpl.gsub(/^### ([^~`\n]+?)\n```ruby(.+?)^```/m) do |x|
    title, code = $1, $2
    
    File.open("tmp.rb", "w:utf-8") do |f|
      f.puts "require 'unmangler'"
      f.puts code
    end

    puts "[.] #{title} .. "
    out = `ruby -Ilib tmp.rb`
    exit unless $?.success?

    x.sub code, code+"\n  # output:\n"+out.split("\n").map{|x| "  #{x}"}.join("\n")+"\n"
  end
  File.unlink("tmp.rb") rescue nil
  File.open('README.md','w'){ |f| f << result }
  #puts result
end
