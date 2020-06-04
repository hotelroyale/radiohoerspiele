# frozen_string_literal: true

require 'feedjira/podcast'
require 'open-uri'
require 'yaml'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/string'
require 'digest/sha1'
require 'fileutils'
require 'json'
require 'reverse_markdown'
# require 'byebug'

def sanatize_filename(filename)
  filename.downcase
          .strip
          .gsub(/ä/, 'ae')
          .gsub(/ü/, 'ue')
          .gsub(/ö/, 'oe')
          .gsub(/ß/, 'ss')
          .gsub(/\-+$/, '')
          .gsub(/^\-+/, '')
          .parameterize
end

def extract_german_date(description)
  matches = description.match(/\d+{1,2}\.\d+{1,2}\.\d+{4}/)
  Date.strptime(matches[0], "%d.%m.%Y") if matches && matches[0]
end

def extract_file_extension(name)
  return name if name.blank?

  name = name.match(/\.[^\.]+$/)[0]
  name.gsub(/^\./, '').gsub(/([a-zA-Z0-9]+).*$/, '\\1')
end

class PodcastDownloader
  class SkipFileError < StandardError; end

  def swr_extract_data_from_website(url)
    doc = Nokogiri::HTML(open(url, 'User-Agent' => 'Mozilla/5.0 (X11; CrOS i686 2268.111.0) AppleWebKit/536.11 (KHTML, like Gecko) Chrome/20.0.1132.57 Safari/536.11'))
    {
      Image: doc.css('meta[name="twitter:image"]')[0].attribute('content').value,
      MediaURL: doc.css('meta[name="twitter:player:stream"]')[0].attribute('content').value
    }
  end

  def download(
    title:,
    author:,
    description:,
    keywords: nil,
    link:,
    audio_url:,
    pub_date: nil,
    broadcaster:,
    image_url:,
    guid:,
    content_source: nil,
    excerpt: nil,
    podcast_url: nil)
    data = {
      Title: title,
      Author: author,
      Description: description,
      Keywords: keywords,
      Link: link,
      MediaURL: audio_url,
      PubDate: pub_date,
      Broadcaster: broadcaster,
      Image: image_url,
      ContentSource: content_source,
      Excerpt: excerpt,
      PodcastURL: podcast_url,
      GUID: guid
    }
    data = data.filter { |v| v.present? }

    unless data[:MediaURL].present?
      if data[:Link].match?(/www\.swr\.de/)
        swr_data = swr_extract_data_from_website(data[:Link])
        data[:MediaURL] = swr_data[:MediaURL]
        data[:Image] = swr_data[:Image] if !data[:Image] || data[:Image].blank?
      else
        raise Error("No MediaURL present for #{guid}")
      end
    end

    filename = [
      data[:Author] ? sanatize_filename(data[:Author]) : nil,
      data[:Title].size > 150 ? sanatize_filename(data[:Title][0...150]) : sanatize_filename(data[:Title]),
      data[:PubDate] ? data[:PubDate].year : nil
    ].reject(&:nil?).join('_')
    filename = sanatize_filename(filename)

    audiofiles_dir = "audiofiles"
    base_dir = "#{audiofiles_dir}/#{broadcaster}"

    Dir.mkdir(audiofiles_dir) unless File.directory?(audiofiles_dir)
    Dir.mkdir(base_dir) unless File.directory?(base_dir)

    directory = "#{base_dir}/#{filename}"

    directory_exists = File.directory?(directory)

    audio_filename = "#{directory}/#{filename}.#{extract_file_extension(data[:MediaURL])}"

    json_file = "#{directory}/audio.json"
    cover_filename = data[:Image].present? ? "#{directory}/cover.#{extract_file_extension(data[:Image])}" : nil

    rename_on_guid_conflicts = true

    if directory_exists
      if File.exist?(json_file)
        existing_json_data = JSON.parse(File.read(json_file))
        if data[:GUID] && existing_json_data['GUID'] && existing_json_data['GUID'] != data[:GUID]
          renamed_dir = "#{directory}__conflict_#{Digest::SHA1.hexdigest(existing_json_data['GUID'])[0...4]}"
          if File.directory?(renamed_dir) || File.directory?(renamed_dir.sub(/__conflict_/, '__part_'))
            raise SkipFileError.new("#{directory} -> #{renamed_dir}")
          end
          if rename_on_guid_conflicts
            puts "Warning: Renaming because of guid/folder-name conflict #{directory} -> #{renamed_dir}"
            FileUtils.mv(directory, renamed_dir)
          else
            raise SkipFileError.new("Podcats GUID conflicts with existing #{json_file}\nnew: #{data[:GUID]}\nexisting: #{existing_json_data['GUID']}")
          end
        else
          raise SkipFileError.new(directory)
        end
      else
        raise SkipFileError.new(directory)
      end
    end

    Dir.mkdir(directory) unless File.directory?(directory)

    if cover_filename && !File.exist?(cover_filename)
      `curl -L #{data[:Image]} -s -o #{cover_filename}`
    end

    puts "-> #{directory}"

    if extract_file_extension(data[:MediaURL]) == 'm3u8'
      # we have a mp4 stream (sometimes @ dlf)
      audio_filename = "#{directory}/#{filename}.mp4"
      `ffmpeg -i '#{data[:MediaURL]}' -bsf:a aac_adtstoasc -vcodec copy -c copy -crf 50 '#{audio_filename}'`
    else
      download_audio_via_curl_command = "curl -L --progress-bar '#{data[:MediaURL]}' -o '#{audio_filename}'"
      `#{download_audio_via_curl_command}`
    end

    data[:FileSHA1] = Digest::SHA1.file(audio_filename).to_s

    File.write json_file, JSON.pretty_generate(data)
  end
end

class AudioplayDownloader
  def exclude_guids
    lines = File.read('./ignore_podcast_guids').chomp.lines.map { |l| l.strip } + File.read('./global_ignore_podcast_guids').chomp.lines.map { |l| l.strip }
    lines.uniq
  end

  def podcasts
    JSON.parse(File.read('./podcasts.json'))
  end

  def download_from_json(json_file)
    broadcaster = File.basename(json_file).sub(/\..+?$/,'')
    items = JSON.parse(File.read(json_file))
    items.each do |item|
      guid = item['GUID'].to_s
      next if exclude_guids.include?(guid)

      pub_date = item['Description'] ? extract_german_date(item['Description']) : nil

      PodcastDownloader.new.download(
        title: item['Title'],
        description: item['Description'],
        image_url: item['Image'],
        author: item['Author'],
        pub_date: pub_date,
        link: item['Link'],
        audio_url: item['MediaURL'],
        broadcaster: broadcaster,
        guid: item['GUID'],
        content_source: item['ContentSource'],
        excerpt: item['Excerpt']
      )
    rescue PodcastDownloader::SkipFileError => e
      puts "Skipping directory because it already exists: #{e.message}"
    rescue StandardError => e
      pp item
      raise e
    end
  end

  def broadcaster_is_dlf_with_html_description
    ['dlfkultur', 'kakadu']
  end

  def download_podcasts
    podcasts.each do |broadcaster, url|
      broadcaster = broadcaster.to_s
      xml = open(url, &:read)
      feed = Feedjira::Feed.parse_with(Feedjira::Parser::Podcast, xml)

      feed.items.each do |item|
        guid = item.guid.guid.to_s
        next if exclude_guids.include?(guid.to_s)

        description = item.description
        image_url = item.itunes_image_href&.to_s

        if broadcaster_is_dlf_with_html_description.include?(broadcaster)
          description_html = item.description
          image_match = description_html.match(/http(s)*:\/\/(www\.)*(deutschlandfunkkultur\.de|kakadu\.de)\/media\/.+?\.jpg/)
          # remove image from description
          description_html = description_html.gsub(/\<img .+?\>/, '') if image_match
          # extract image for cover
          image_url = image_match[0] if image_match
          description = ReverseMarkdown.convert(description_html).split(/Hören bis\:/)[0].chomp.strip
        end

        PodcastDownloader.new.download(
          title: item.title,
          image_url: image_url,
          description: description,
          author: item.itunes_author,
          keywords: item.itunes_keywords,
          link: item.link.to_s,
          audio_url: item.enclosure_url.to_s,
          pub_date: item.pub_date,
          broadcaster: broadcaster,
          podcast_url: url,
          guid: guid.to_s
        )
      rescue PodcastDownloader::SkipFileError => e
        puts "Skipping directory because it already exists: #{e.message}"
      rescue StandardError => e
        pp item
        raise e
      end
    end
  end
end

args = ARGV.dup
action = args.first
available_actions = AudioplayDownloader.new.public_methods.filter { |m| m.to_s.start_with?('download_')}
unless available_actions.include?(action.to_sym)
  raise "Please set as first argument the action. Available actions are #{available_actions.join(', ')}"
end

AudioplayDownloader.new.public_send(action, *args[1..])
