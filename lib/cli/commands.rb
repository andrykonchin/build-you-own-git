require 'dry/cli'
require_relative '../ls_files'

module DIYGit
  module CLI
    module Commands
      extend Dry::CLI::Registry

      # ../diy-git/bin/toy-git ls-files | head -n 10
      # ../diy-git/bin/toy-git ls-files --stage | head -n 10
      # ../diy-git/bin/toy-git ls-files --stage --abbrev=7 | head -n 10
      # ../diy-git/bin/toy-git ls-files --format='hello world %(objecttype) %(path)' | head -n 10
      class LsFiles < Dry::CLI::Command
        desc 'git-ls-files - Show information about files in the index and the working tree'

        option :cached, type: :boolean, desc: 'Show all files cached in Git’s index, i.e. all tracked files. (This is the default if no -c/-s/-d/-o/-u/-k/-m/--resolve-undo options are specified.)'
        option :stage, type: :boolean, desc: 'Show staged contents\' mode bits, object name and stage number in the output.'
        option :deleted, type: :boolean, desc: 'Show files with an unstaged deletion.'
        option :modified, type: :boolean, desc: 'Show files with an unstaged modification (note that an unstaged deletion also counts as an unstaged modification)'

        option :abbrev, type: :integer, desc: 'Instead of showing the full 40-byte hexadecimal object lines, show the shortest prefix that is at least <n> hexdigits long that uniquely refers the object. Non default number of digits can be specified with --abbrev=<n>.'
        option :format, type: :string, desc: 'A string that interpolates %(fieldname) from the result being shown. It also interpolates %% to %, and %xx where xx are hex digits interpolates to character with hex code xx; for example %00 interpolates to \0 (NUL), %09 to \t (TAB) and %0a to \n (LF). --format cannot be combined with -s, -o, -k, -t, --resolve-undo and --eol.'
        option :debug, type: :boolean, desc: 'After each line that describes a file, add more data about its cache entry. This is intended to show as much information as possible for manual inspection; the exact format may change at any time.'

        def call(**options)
          if options[:stage]
            DIYGit::LsFiles::Stage.new.run(options)
          elsif options[:cached]
            DIYGit::LsFiles::Cached.new.run(options)
          elsif options[:modified]
            DIYGit::LsFiles::Modified.new.run(options)
          elsif options[:deleted]
            DIYGit::LsFiles::Deleted.new.run(options)
          else
            DIYGit::LsFiles::Cached.new.run(options)
          end
        end
      end

      register 'ls-files', LsFiles
    end
  end
end

# TODO:
# - https://git-scm.com/docs/git-hash-object
# - https://github.com/git/git/blob/cfb8a6e9a93adbe81efca66e6110c9b4d2e57169/Documentation/git-cat-file.txt#L292
# - https://www.thegeekdiary.com/git-ls-tree-command-examples/
# - https://git-scm.com/docs/git-write-tree
# - https://git-scm.com/docs/git-commit-tree
# - enable file monitor extension
#   - https://github.blog/2022-06-29-improve-git-monorepo-performance-with-a-file-system-monitor/
