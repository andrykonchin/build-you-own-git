require_relative '../index'

module DIYGit
  # Resources
  # - https://github.com/git/git/blob/master/Documentation/gitformat-index.txt
  # - https://git-scm.com/docs/git-ls-files
  module LsFiles
    class Other
      def run(options)
        workdir = Dir.pwd
        index = DIYGit::Index.new(workdir)
        index.parse

        if options[:format]
          puts 'fatal: --format cannot be used with -s, -o, -k, -t, --resolve-undo, --deduplicate, --eol'
          exit 1
        end

        # TODO: find a better way to ignore .git directory
        # TODO: avoid File.directory? excessive calls (that lead to lstat syscalls)
        filenames = Dir.glob("**/*", File::FNM_DOTMATCH)
        filenames -= Dir.glob(".git/**/*")
        filenames = filenames.select { |filename| !File.directory?(filename) }

        filenames.each do |filename|
          # TODO: use binary search as far as entries are already sorted
          found = index.entries.any? { |entry| entry.pathname == filename }

          unless found
            puts filename
          end
        end
      end
    end
  end
end
