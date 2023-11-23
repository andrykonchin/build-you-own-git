require "zlib"

module DIYGit
  class MkTag
    # TODO: not tested
    # TODO: validate format, example:
    #
    #   object 295d29dbe357d582f1d210c37fb11c02ec7b13ea
    #   type commit
    #   tag tag-test-1
    #   tagger Andry Konchin <andry.konchin@test.com> 123456 +0145
    #
    #   test message
    # TODO: support --strict option (or --no-strict?)
    def run(options)
      content = $stdin.read

      write_object("tag", content)

      digest = digest_for_object("tag", content)
      puts digest
    end

    private

    def write_object(type, content)
      header = "%s %d\0" % [type, content.bytesize]
      content_to_zip = header + content
      zipped_content = Zlib::Deflate.deflate(content_to_zip)

      digest = digest_for_object(type, content)

      workdir = Dir.pwd
      path_to_dir = workdir + '/.git/objects/' + digest[0..1]
      path_to_file = path_to_dir + '/' + digest[2..]

      Dir.mkdir(path_to_dir) unless File.exist?(path_to_dir)
      File.write(path_to_file, zipped_content) unless File.exist?(path_to_file)
    end

    def digest_for_object(type, content)
      string = "%s %d\0%s" % [type, content.bytesize, content]
      Digest::SHA1.hexdigest(string)
    end
  end
end
