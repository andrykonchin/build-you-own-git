require 'digest'
require_relative '../index'
require_relative '../pattern'

module DIYGit
  # Resources
  # - https://github.com/git/git/blob/master/Documentation/gitformat-index.txt
  # - https://git-scm.com/docs/git-ls-files
  module LsFiles

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
    class Modified
      def run(options)
        workdir = Dir.pwd
        index = DIYGit::Index.new(workdir)
        index.parse

        if options[:format]
          pattern = Pattern.new(options[:format])
        end

        index.entries.each do |entry|
          next unless modified?(entry)

          if pattern
            puts pattern.apply_to(entry)
          else
            puts entry.pathname
          end

          if options[:debug]
            puts CacheEntryDebugInfo.new(entry).report
          end
        end
      end

      private

      def modified?(entry)
        # unstaged deletion is treated as "modification" as well
        #
        # NOTE: git uses `lstat` syscall and checks whether it fails
        #       and error is either ENOENT or ENOTDIR
        return true unless File.exist?(entry.pathname)

        stat = File.lstat(entry.pathname)

        # compare owner 'x' bit
        mode_cached = entry.mode.value
        mode_actual = stat.mode
        mode_changed = (mode_actual ^ mode_cached) & 0100 != 0

        return true if mode_changed

        # check file type
        type_changed = (mode_actual && 0x8000) != (mode_cached & 0x8000)
        return true if type_changed

        # check data (file content) change
        data_changed = entry.file_size != stat.size

        unless data_changed
          type = "blob"
          file_size = entry.file_size

          # NOTE: Git reads at once only files up to 32 KB.
          #       Larger files are handled with mmap syscall.
          #       There is special case for huge files bigger than 512 MB.
          file_content = File.read(entry.pathname, encoding: "ASCII-8BIT")

          string_to_hash = "%s %d\0%s" % [type, file_size, file_content]
          digest = Digest::SHA1.hexdigest(string_to_hash)

          data_changed = (entry.object_name.hex != digest)
        end

        return true if data_changed

        return false
      end
    end
  end
end
