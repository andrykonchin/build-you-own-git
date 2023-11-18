require 'digest'
require_relative '../index'
require_relative '../pattern'

module DIYGit
  # Resources
  # - https://github.com/git/git/blob/master/Documentation/gitformat-index.txt
  # - https://git-scm.com/docs/git-ls-files
  module LsFiles
    class Deleted
      def run(options)
        workdir = Dir.pwd
        index = DIYGit::Index.new(workdir)
        index.parse

        if options[:format]
          pattern = Pattern.new(options[:format])
        end

        index.entries.each do |entry|
          # NOTE: git uses `lstat` syscall and checks whether it fails
          #       and error is either ENOENT or ENOTDIR
          next if File.exist?(entry.pathname)

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
    end
  end
end
