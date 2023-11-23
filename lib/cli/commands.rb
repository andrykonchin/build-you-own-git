require 'dry/cli'
require_relative '../ls_files'
require_relative '../hash_object'
require_relative '../cat_file'
require_relative '../mk_tag'
require_relative '../ls_tree'

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
        option :other, type: :boolean, desc: 'Show other (i.e. untracked) files in the output'

        option :abbrev, type: :integer, desc: 'Instead of showing the full 40-byte hexadecimal object lines, show the shortest prefix that is at least <n> hexdigits long that uniquely refers the object. Non default number of digits can be specified with --abbrev=<n>.'
        option :format, type: :string, desc: 'A string that interpolates %(fieldname) from the result being shown. It also interpolates %% to %, and %xx where xx are hex digits interpolates to character with hex code xx; for example %00 interpolates to \0 (NUL), %09 to \t (TAB) and %0a to \n (LF). --format cannot be combined with -s, -o, -k, -t, --resolve-undo and --eol.'
        option :debug, type: :boolean, desc: 'After each line that describes a file, add more data about its cache entry. This is intended to show as much information as possible for manual inspection; the exact format may change at any time.'

        def call(**options)
          # TODO: handle combinations on --modified/--deleted/--stage etc - file name are merged somehow
          # TODO: handle running in a subdirectory
          # TODO: use Index Entry Offset Table to load entries in parallel
          #
          # NOTE: doesn't support:
          # - a sparse index
          # - links and git links
          # - git filters
          # - configuration
          if options[:stage]
            DIYGit::LsFiles::Stage.new.run(options)
          elsif options[:cached]
            DIYGit::LsFiles::Cached.new.run(options)
          elsif options[:modified]
            DIYGit::LsFiles::Modified.new.run(options)
          elsif options[:deleted]
            DIYGit::LsFiles::Deleted.new.run(options)
          elsif options[:other]
            DIYGit::LsFiles::Other.new.run(options)
          else
            DIYGit::LsFiles::Cached.new.run(options)
          end
        end
      end

      class HashObject < Dry::CLI::Command
        # TODO: add long description, not only NAME
        desc 'git-hash-object - Compute object ID and optionally create an object from a file'

        option :t, type: :string, desc: 'Specify the type of object to be created (default: "blob"). Possible values are commit, tree, blob, and tag'
        option :stdin, type: :boolean, desc: 'Read the object from standard input instead of from a file.'
        option :w, type: :boolean, desc: 'Actually write the object into the object database.'

        def call(**options)
          DIYGit::HashObject.new.run(options)
        end
      end

      class CatFile < Dry::CLI::Command
        desc 'git-cat-file - Provide contents or details of repository objects'

        option :s, type: :boolean, desc: 'Instead of the content, show the object size identified by <object>. If used with --use-mailmap option, will show the size of updated object after replacing idents using the mailmap mechanism.'

        def call(**options)
          DIYGit::CatFile.new.run(options)
        end
      end

      class MkTag < Dry::CLI::Command
        desc 'git-mktag - Creates a tag object with extra validation'

        def call(**options)
          DIYGit.new.run(options)
        end
      end

      class LsTree < Dry::CLI::Command
        desc 'git-ls-tree - List the contents of a tree object'

        option :"name-only", type: :boolean, aliases: ['name-status'], desc: 'List only filenames (instead of the "long" output), one per line. Cannot be combined with --object-only.'
        option :"object-only", type: :boolean, desc: %q{List only names of the objects, one per line. Cannot be combined with --name-only or --name-status. This is equivalent to specifying --format='%(objectname)', but for both this option and that exact format the command takes a hand-optimized codepath instead of going through the generic formatting mechanism.}
        option :abbrev, type: :integer, desc: 'Instead of showing the full 40-byte hexadecimal object lines, show the shortest prefix that is at least <n> hexdigits long that uniquely refers the object. Non default number of digits can be specified with --abbrev=<n>.'
        option :long, type: :boolean, aliases: ['l'], desc: 'Show object size of blob (file) entries.'
        option :r, type: :boolean, desc: 'Recurse into sub-trees.'
        option :t, type: :boolean, desc: 'Show tree entries even when going to recurse them. Has no effect if -r was not passed. -d implies -t.'
        option :d, type: :boolean, desc: 'Show only the named tree entry itself, not its children.'

        argument :treeish, required: true, desc: 'Id of a tree-ish'

        def call(**options)
          # TODO: order of options in command affects order of names in error messages
          if options[:"name-only"] && options[:"object-only"]
            puts "error: option `name-only' is incompatible with --object-only"
            exit 1
          end

          # TODO: order of options in command affects order of names in error messages
          if options[:"name-status"] && options[:"object-only"]
            puts "error: option `name-status' is incompatible with --object-only"
            exit 1
          end

          # TODO: order of options in command affects order of names in error messages
          if options[:long] && options[:"name-only"]
            puts "error: option `name-only' is incompatible with --long"
            exit 1
          end

          # TODO: order of options in command affects order of names in error messages
          if options[:long] && options[:"object-only"]
            puts "error: option `object-only' is incompatible with --long"
            exit 1
          end

          DIYGit::LsTree.new.run(options)
        end
      end

      register 'ls-files', LsFiles
      register 'hash-object', HashObject
      register 'cat-file', CatFile
      register 'mktag', MkTag
      register 'ls-tree', LsTree
    end
  end
end

# TODO:
#
# https://git-scm.com/docs/git
#
# - https://git-scm.com/docs/git-hash-object
# - https://github.com/git/git/blob/cfb8a6e9a93adbe81efca66e6110c9b4d2e57169/Documentation/git-cat-file.txt#L292
# - https://www.thegeekdiary.com/git-ls-tree-command-examples/
# - https://git-scm.com/docs/git-read-tree
# - https://git-scm.com/docs/git-write-tree
# - https://git-scm.com/docs/git-commit-tree
# - https://git-scm.com/docs/git-update-index
#
# - enable file monitor extension
#   - https://github.blog/2022-06-29-improve-git-monorepo-performance-with-a-file-system-monitor/
