
require 'digest'

conflict_files = Dir.glob("./audiofiles/*/*__conflict_*/*.mp*")
dry_run = true

conflict_files.each do |file|
  original_file = file.sub(/__conflict_[a-e0-9]{4}/, '')
  unless File.exist?(original_file)
    STDERR.puts("Skipping #{file} because there is no corresponding file to compare")
    next
  end

  checksum_of_conflicting_file = Digest::SHA1.file(file).to_s
  checksum_of_original_file = Digest::SHA1.file(original_file).to_s
  if checksum_of_original_file == checksum_of_conflicting_file && File.dirname(file) != File.dirname(original_file)
    puts "rm -rf #{File.dirname(original_file)} && mv #{File.dirname(file)} #{File.dirname(original_file)}"
  else
    # rename
    folder = File.dirname(file)
    puts "# found new file"
    puts "mv #{folder} #{folder.sub(/__conflict_/, '__part_')}"
  end
end
