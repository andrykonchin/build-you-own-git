require 'digest'
require_relative '../index'

module DIYGit
  # Resources
  # - https://github.com/git/git/blob/master/Documentation/gitformat-index.txt
  # - https://git-scm.com/docs/git-ls-files
  module LsFiles
    class Cached
      def run(options)
        workdir = Dir.pwd
        index = DIYGit::Index.new(workdir)
        index.parse

        index.entries.each do |entry|
          if options[:deleted]
            # NOTE: git uses `lstat` syscall and checks whether it fails
            #       and error is either ENOENT or ENOTDIR
            next if File.exist?(entry.pathname)
          end

          # Handle only regular file case.
          #
          # NOTE: Git handles edge cases - when file is a link or a git link.
          #       Ignore them for simplicity.
          #
          # NOTE: Git also handles situations when file size stored in index is zero
          #       that may mean that it's a temporary incorrect value and file
          #       content should be checked instead.
          #
          # NOTE: Git handles race of adding file into an index and modifying
          #       this file. So Git doesn't rely on file size and checks actual file
          #       content.
          #
          # See ie_modified and ce_match_stat_basic functions in read-cache.c
          # and index_core and hash_object_file in object-file.c
          #
          # Check MODE_CHANGED | TYPE_CHANGED | DATA_CHANGED
          if options[:modified]
            # unstaged deletion is treated as "modification" as well
            next unless File.exist?(entry.pathname)

            stat = File.lstat(entry.pathname)

            # compare owner 'x' bit
            mode_cached = entry.mode.value
            mode_actual = stat.mode
            mode_changed = (mode_actual ^ mode_cached) & 0100 != 0

            # check file type
            type_changed = (mode_actual && 0x8000) != (mode_cached & 0x8000)

            # check data (file content) change
            data_changed = entry.file_size != stat.size

            unless data_changed
              type = "blob"
              file_size = entry.file_size

              # NOTE: Git reads at once only files up to 32 KB.
              #       Larger files are handled with mmap syscall.
              file_content = File.read(entry.pathname, encoding: "ASCII-8BIT")

              string_to_hash = "%s %d\0%s" % [type, file_size, file_content]
              digest = Digest::SHA1.hexdigest(string_to_hash)

              data_changed = (entry.object_name.hex != digest)
            end

            next if !mode_changed && !type_changed && !data_changed
          end

          puts entry.pathname
        end
      end
    end
  end
end
