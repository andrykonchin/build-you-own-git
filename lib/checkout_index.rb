require 'digest'
require 'pathname'
require_relative 'index'

module DIYGit
  # Resources
  # - https://github.com/git/git/blob/master/Documentation/gitformat-index.txt
  # - https://git-scm.com/docs/git-checkout-index
  class CheckoutIndex
    def run(options)
      if options[:all]
        workdir = Dir.pwd
        index = DIYGit::Index.new(workdir)
        index.parse

        index.entries.each do |entry|
          pathname_to_write = (options[:prefix] || '') + entry.pathname

          if File.exist?(pathname_to_write)
            puts "file #{pathname_to_write} exists" # TODO: handle it properly - there are options --force etc
            next
          end

          _, _, content = load_object(entry.object_name.hex)

          FileUtils.mkdir_p(Pathname.new(pathname_to_write).dirname)
          File.write(pathname_to_write, content.b, encoding: 'ASCII-8BIT')
        end
      else
        workdir = Dir.pwd
        index = DIYGit::Index.new(workdir)
        index.parse

        options[:args].each do |pathname|
          entry = index.entries.find { |e| e.pathname == pathname }

          unless entry
            puts "git checkout-index: #{pathname} is not in the cache"
            exit 1
          end

          pathname_to_write = (options[:prefix] || '') + pathname

          if File.exist?(pathname_to_write)
            puts "file #{pathname_to_write} exists" # TODO: handle it properly - there are options --force etc
            next
          end

          _, _, content = load_object(entry.object_name.hex)

          File.write(pathname_to_write, content.b, encoding: 'ASCII-8BIT')
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
      header, content = header_with_content.split("\0")

      type, size = header.split(' ')

      [type, size, content]
    end
  end
end
