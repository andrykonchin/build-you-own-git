module DIYGit
  class HashObject
    def run(options)
      # TODO: support types other than blob (or at least add validation - check that content has correct structure)
      # TODO: support writing object into database (-w)
      # TODO: support other related to -w options - --path, --stdin-paths, --no-filters
      # TODO: support --literally
      return unless options[:t] == "blob" || options[:t].nil?

      if options[:stdin]
          type = options[:t] || "blob"
          content = $stdin.read
          size = content.b.size
          digest = digest_for_object(type, size, content)

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
          type = options[:t] || "blob"
          file_size = File.size(filename)
          file_content = File.read(filename, encoding: "ASCII-8BIT")
          digest = digest_for_object(type, file_size, file_content)

          puts digest
        end
      end
    end

    private

    def digest_for_object(type, size, content)
      string = "%s %d\0%s" % [type, size, content]
      Digest::SHA1.hexdigest(string)
    end
  end
end
