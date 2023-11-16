require_relative '../index'

module DIYGit
  # Resources
  # - https://github.com/git/git/blob/master/Documentation/gitformat-index.txt
  # - https://git-scm.com/docs/git-ls-files
  module LsFiles
    class Format
      def run(options)
        workdir = Dir.pwd
        index = DIYGit::Index.new(workdir)
        index.parse

        pattern = Pattern.new(options[:format])

        # TODO: apply abbrev
        index.entries.each do |entry|
          line = pattern.apply_to(entry)
          puts line
        end
      end

      class Pattern
        PLACEHOLDERS = %i(objectmode objecttype objectname objectsize stage path)

        def initialize(pattern)
          @pattern = pattern

          # NOTE: Actual error message contains also invail fragment of a format string.
          #       Skip it for simplicity.
          if @pattern =~ /%(?!\((#{ PLACEHOLDERS.join('|') })\))/ # '%' + not '(' any placeholder ')'
              puts "fatal: bad ls-files format #{@pattern}"
            exit 1
          end

          @indices = PLACEHOLDERS.zip(PLACEHOLDERS.map { |p| @pattern.index("%(#{p})") }).select { _2 }.sort_by { _2 }
        end

        def apply_to(entry)
          line = @pattern.dup

          @indices.reverse_each do |placeholder, index|
            value = case placeholder
                    when :objectmode
                      entry.mode
                    when :objecttype
                      entry.mode.object_type_name
                    when :objectname
                      entry.object_name.hex
                    when :objectsize
                      entry.file_size
                    when :stage
                      entry.flags.stage_number
                    when :path
                      entry.pathname
                    else
                      raise "Shouldn't reach here: unknown placeholder #{placeholder}"
                    end

            line[index, "%(#{placeholder})".size] = value.to_s
          end

          line
        end
      end
    end
  end
end
