require "zlib"

module DIYGit
  class HashObject
    def run(options)
      # TODO: support types other than blob (or at least add validation - check that content has correct structure)
      # TODO: support other related to -w options - --path, --stdin-paths, --no-filters
      # TODO: support --literally
      return unless options[:t] == "blob" || options[:t].nil?

      # TODO: check if specified type value is correct
      type = options[:t] || "blob"

      if options[:stdin]
        content = $stdin.read.b
        size = content.size
        digest = digest_for_object(type, size, content)

        if options[:w]
          write_object(digest, type, content)
        end

        puts digest
      end

      # [--] <file>...
      if options[:args]
        args = options[:args] || []

        args.each do |filename|
          unless File.exist?(filename)
            puts "fatal: could not open '#{filename}' for reading: No such file or directory"
            exit 1
          end

          # NOTE: Git reads at once only files up to 32 KB.
          #       Larger files are handled with mmap syscall.
          #       There is special case for huge files bigger than 512 MB.
          content = File.read(filename, encoding: "ASCII-8BIT").b
          size = content.size
          digest = digest_for_object(type, size, content)

          if options[:w]
            write_object(digest, type, content)
          end

          puts digest
        end
      end
    end

    private

    def digest_for_object(type, size, content)
      string = "%s %d\0%s" % [type, size, content]
      Digest::SHA1.hexdigest(string)
    end

    def write_object(digest, type, content)
      header = "%s %d\0" % [type, content.size]
      content_to_zip = header + content
      zipped_content = Zlib::Deflate.deflate(content_to_zip)

      workdir = Dir.pwd
      path_to_dir = workdir + '/.git/objects/' + digest[0..1]
      path_to_file = path_to_dir + '/' + digest[2..]

      Dir.mkdir(path_to_dir) unless File.exist?(path_to_dir)
      File.write(path_to_file, zipped_content) unless File.exist?(path_to_file)
    end
  end
end
