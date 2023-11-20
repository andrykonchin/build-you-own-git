require "zlib"

module DIYGit
  class CatFile
    def run(options)
      if options[:args]
        # TODO: use pattern matching
        if options[:args].size == 2
          type, object = options[:args]
        else options[:args].size == 1
          type, = options[:args]
        end
      end

      if type == "blob"
        dirname = object[0..1]
        filename_prefix = object[2..]

        workdir = Dir.pwd
        path_to_dir = workdir + '/.git/objects/' + dirname

        unless Dir.exist?(path_to_dir)
          puts "fatal: Not a valid object name #{object}"
          exit 1
        end

        filenames = Dir.children(path_to_dir).select { |filename| filename.start_with?(filename_prefix) }
        if filenames.size != 1
          puts "fatal: git cat-file #{object}: bad file"
          exit 1
        end

        filename = filenames[0]

        content_zipped = File.read(path_to_dir + '/' + filename)
        header_with_content = Zlib::Inflate.inflate(content_zipped)
        header, content = header_with_content.split("\0")

        if options[:s]
          _, size = header.split(" ")
          puts size
        else
          puts content
        end
      end
    end
  end
end

