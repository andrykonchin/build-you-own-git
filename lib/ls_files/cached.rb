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
          puts entry.pathname
        end
      end
    end
  end
end
