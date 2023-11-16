require 'dry/cli'
require_relative '../ls_files'

module DIYGit
  module CLI
    module Commands
      extend Dry::CLI::Registry

      class LsFiles < Dry::CLI::Command
        desc 'git-ls-files - Show information about files in the index and the working tree'

        option :cached, type: :boolean, default: true, desc: 'Show all files cached in Git’s index, i.e. all tracked files. (This is the default if no -c/-s/-d/-o/-u/-k/-m/--resolve-undo options are specified.)'
        option :stage, type: :boolean, default: false, desc: 'Show staged contents\' mode bits, object name and stage number in the output.'
        option :abbrev, type: :integer, desc: 'Instead of showing the full 40-byte hexadecimal object lines, show the shortest prefix that is at least <n> hexdigits long that uniquely refers the object. Non default number of digits can be specified with --abbrev=<n>.'
        option :format, type: :string, desc: 'A string that interpolates %(fieldname) from the result being shown. It also interpolates %% to %, and %xx where xx are hex digits interpolates to character with hex code xx; for example %00 interpolates to \0 (NUL), %09 to \t (TAB) and %0a to \n (LF). --format cannot be combined with -s, -o, -k, -t, --resolve-undo and --eol.'

        def call(**options)
          if options[:format]
            DIYGit::LsFiles::Format.new.run(options)
          elsif options[:stage]
            DIYGit::LsFiles::Stage.new.run(options)
          elsif options[:cached]
            DIYGit::LsFiles::Cached.new.run(options)
          end
        end
      end

      register 'ls-files', LsFiles
    end
  end
end
