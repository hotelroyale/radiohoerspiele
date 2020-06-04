
require 'yaml'
require 'json'
require 'digest'
require 'open-uri'
require 'nokogiri'

yaml_files = Dir.glob("./audiofiles/**/*.yml")

yaml_files.each do |file|
  yaml_data = YAML.load_file(file)
  json_file = file.sub(/\/[^\/]+?\.yml/, '/audio.json')

  unless File.exists?(json_file)
    # STDERR.puts "No corresponding json file (#{json_file}) found for #{file}"
    unless yaml_data['FileSHA1']
      audio_filename = file.sub(/\.yml$/, '.mp3')
      audiofile = Dir.glob(file.sub(/\.yml$/, '.mp*'))[0]
      if (!audiofile || !File.exists?(audiofile)) && (!yaml_data['MediaURL'] || yaml_data['MediaURL'].empty?)
        doc = Nokogiri::HTML(open(yaml_data['Link'], 'User-Agent' => 'Mozilla/5.0 (X11; CrOS i686 2268.111.0) AppleWebKit/536.11 (KHTML, like Gecko) Chrome/20.0.1132.57 Safari/536.11'))
        url = doc.css('meta[name="twitter:player:stream"]')[0].attribute('content').value
        `curl -L --progress-bar #{url} -o #{audio_filename}`
      end
      yaml_data['FileSHA1'] = Digest::SHA1.file(audiofile || audio_filename)
    end
    puts "-> #{json_file}"
    File.write json_file, JSON.pretty_generate(yaml_data)
  end

  json_data = JSON.parse(File.read(json_file))

  if json_data['GUID'] != yaml_data['GUID']
    puts "#{file} -> GUID mismatch"
  end
end

