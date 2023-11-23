require "zlib"
require "stringio"
require_relative "stream"

module DIYGit
  # Resources
  # - https://git-scm.com/docs/git-ls-tree
  class LsTree
    def run(options)
      id = options[:treeish]

      # TODO: handle other cases
      # object name
      if id =~ /\A[0-9a-f]+\z/
        type, _, content = load_object(id)

        # content:
        #   tree e30739e66c67b29954ed6d4002881358ac2a866b
        #   parent 295d29dbe357d582f1d210c37fb11c02ec7b13ea
        #   author Andrew Konchin <andry.konchin@gmail.com> 1700006368 +0200
        #   committer Andrew Konchin <andry.konchin@gmail.com> 1700006368 +0200
        #
        #   handle invalid TREE entries

        tree_header = content.lines.find { |line| line =~ /\Atree [0-9a-f]{40}\Z/ }
        _, tree_object_name = tree_header.split(' ')
        _, _, tree_content = load_object(tree_object_name)

        io = StringIO.new(tree_content)
        stream = Stream.new(io)

        mode = Stream::TerminatedString.new(' ')
        filename = Stream::TerminatedString.new("\0")
        object_name = Stream::BinaryString.new(20)

        while !io.eof?
          stream >> mode >> filename >> object_name

          mode_value = Integer(mode.value, 8)
          type = (mode.value == '040000') ? 'tree' : 'blob' # TODO: not accurate - there might be other types
          string = "%06o %s %s\t%s" % [mode_value, type, object_name.hex, filename.value]

          puts string
        end
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
        puts "fatal: git cat-file #{id}: bad file"
        exit 1
      end

      filename = filenames[0]

      content_zipped = File.read(path_to_dir + '/' + filename)
      header_with_content = Zlib::Inflate.inflate(content_zipped)
      header, _, content = header_with_content.partition("\0")
      type, size = header.split(' ')

      [type, size, content]
    end
  end
end
