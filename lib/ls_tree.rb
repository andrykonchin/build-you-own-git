require "zlib"
require "stringio"
require "pathname"
require_relative "stream"

module DIYGit
  # Resources
  # - https://git-scm.com/docs/git-ls-tree
  class LsTree
    # TODO: support options:
    # - --full-name
    # - --full-tree
    # - --format
    # [<path>…​]
    def run(options)
      id = options[:treeish]

      # TODO: handle other cases
      # object name
      if id =~ /\A[0-9a-f]+\z/
        type, _, content = load_object(id)

        return if type.empty? # TODO: temporary workaroung until we support packed files

        # content:
        #   tree e30739e66c67b29954ed6d4002881358ac2a866b
        #   parent 295d29dbe357d582f1d210c37fb11c02ec7b13ea
        #   author Andrew Konchin <andry.konchin@gmail.com> 1700006368 +0200
        #   committer Andrew Konchin <andry.konchin@gmail.com> 1700006368 +0200
        #
        #   handle invalid TREE entries

        tree_header = content.lines.find { |line| line =~ /\Atree [0-9a-f]{40}\Z/ }
        _, tree_object_name = tree_header.split(' ')

        ls_tree(tree_object_name, options, path: '')
      end
    end

    def load_object(id)
      dirname = id[0..1]
      filename_prefix = id[2..]

      workdir = Dir.pwd
      path_to_dir = workdir + '/.git/objects/' + dirname

      unless Dir.exist?(path_to_dir)
        puts "fatal: Not a valid object name #{id}"
        exit 1
      end

      filenames = Dir.children(path_to_dir).select { |filename| filename.start_with?(filename_prefix) }
      if filenames.size != 1
        # TODO: some files aren't present in .git/objects directory - probably they are packed
        return ['', 0, '']
        #puts "fatal: git cat-file #{id}: bad file"
        #exit 1
      end

      filename = filenames[0]

      content_zipped = File.read(path_to_dir + '/' + filename)
      header_with_content = Zlib::Inflate.inflate(content_zipped)
      header, _, content = header_with_content.partition("\0")
      type, size = header.split(' ')

      [type, size, content]
    end

    def ls_tree(tree_object_name, options, path:)
      _, _, tree_content = load_object(tree_object_name)

      io = StringIO.new(tree_content)
      stream = Stream.new(io)

      mode = Stream::TerminatedString.new(' ')
      filename = Stream::TerminatedString.new("\0")
      object_name = Stream::BinaryString.new(20)

      while !io.eof?
        stream >> mode >> filename >> object_name

        type = (mode.value == '40000') ? 'tree' : 'blob' # TODO: not accurate - there might be other types

        if (type == 'blob' && !options[:d]) || (type == 'tree' && (!options[:r] || options[:t] || options[:d]))
          if options[:"name-only"]
            puts Pathname.new(path).join(filename.value).to_s
          elsif options[:"object-only"]
            # TODO: abbrev handling is a bit more complex
            if options[:abbrev]
              abbrev = Integer(options[:abbrev])

              if abbrev <= 0
                abbrev = 20
              end

              puts object_name.hex[0, abbrev]
            else
              puts object_name.hex
            end
          else
            mode_value = Integer(mode.value, 8)

            if options[:long]
              size = \
                if type == 'blob'
                  _, blob_size, _ = load_object(object_name.hex)
                  blob_size.to_s
              else
                '-'
              end

              string = "%06o %s %s %7s\t%s" % [mode_value, type, object_name.hex, size, filename.value]
              puts string
            else
              string = "%06o %s %s\t%s" % [mode_value, type, object_name.hex, Pathname.new(path).join(filename.value).to_s]
              puts string
            end
          end
        end

        if options[:r] && type == 'tree'
          ls_tree(object_name.hex, options, path: Pathname.new(path).join(filename.value).to_s)
          next
        end
      end
    end
  end
end
