
require 'yaml'

filter = ARGV.last || '**'

yaml_files = Dir.glob("./audiofiles/#{filter}/audio.json")
files = {}

guids = yaml_files.map do |file|
  data =YAML.load_file(file)
  raise("Couldn't find GUID in #{file}") unless data['GUID']
  files[data['GUID']] ||= []
  files[data['GUID']] << file
  data['GUID']
end

puts guids

if guids.size != guids.uniq.size
  STDERR.puts "====="
  STDERR.puts files.filter { |k,v| v.size > 1 }.map {|k,v| v.map { |yaml_file| File.dirname(yaml_file) } }
  STDERR.puts "WARNING: Found #{guids.size - guids.uniq.size} dub guids"
end

