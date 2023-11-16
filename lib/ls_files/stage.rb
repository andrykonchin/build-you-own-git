require_relative '../index'

module DIYGit
  # Resources
  # - https://github.com/git/git/blob/master/Documentation/gitformat-index.txt
  # - https://git-scm.com/docs/git-ls-files
  module LsFiles
    class Stage
      def run(options)
        workdir = Dir.pwd
        index = DIYGit::Index.new(workdir)
        index.parse

        if options[:abbrev]
          abbrev = Integer(options[:abbrev])

          if abbrev <= 0
            # NOTE: actually git's behavior:
            #  - 0 - means full length (20 characters), but
            #  - negative - by some reason prints only 4 characters
            abbrev = nil
          end
        end

        index.entries.each do |entry|
          object_name = options[:abbrev] ? entry.object_name.hex[0, abbrev] : entry.object_name.hex
          line = "%s %s %s\t%s" % [entry.mode.value.to_s(8), object_name, entry.flags.stage_number, entry.pathname]
          puts line
        end
      end
    end
  end
end
