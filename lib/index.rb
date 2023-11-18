require_relative 'assert'
require_relative 'stream'

# Resources
# - https://github.com/git/git/blob/master/Documentation/gitformat-index.txt
# - https://mincong.io/2018/04/28/git-index/

module DIYGit
  class Index
    include Assert

    attr_reader :workdir, :entries, :signature, :version, :entries_number

    def initialize(workdir)
      @workdir = workdir
      @entries = []
    end

    def parse
      f = File.open(@workdir + '/.git/index', encoding: 'binary')
      stream = Stream.new(f)

      signature = Stream::BinaryString.new(4)
      version, entries_number = Stream::Int32.new, Stream::Int32.new

      stream >> signature >> version >> entries_number # => ["DIRC", 2, 13430]
      @signature = signature.value
      @version = version.value
      @entries_number = entries_number.value

      @entries_number.times do
        ctime_seconds, ctime_nanoseconds, mtime_seconds, mtime_nanoseconds,
        dev, ino, mode, uid, gid, file_size = [
          Stream::Int32.new, Stream::Int32.new, Stream::Int32.new, Stream::Int32.new, Stream::Int32.new,
          Stream::Int32.new, Stream::Int32.new, Stream::Int32.new, Stream::Int32.new, Stream::Int32.new
        ]

        object_name = Stream::BinaryString.new(20)
        flags = Stream::Int16.new

        stream >> ctime_seconds >> ctime_nanoseconds >> mtime_seconds >> mtime_nanoseconds >> dev >> ino >> mode >> uid >> gid >> file_size
        stream >> object_name
        stream >> flags

        pathname_size = Flags.new(flags.value).pathname_size
        padding_size = (8 - (62 + pathname_size + 1) % 8) % 8

        pathname = Stream::BinaryString.new(pathname_size)
        padding = Stream::BinaryString.new(padding_size + 1) # pathname ending '\0' + padding '\0's
        stream >> pathname >> padding

        entry = Entry.new(
          ctime_seconds: ctime_seconds.value,
          ctime_nanoseconds: ctime_nanoseconds.value,
          mtime_seconds: mtime_seconds.value,
          mtime_nanoseconds: mtime_nanoseconds.value,
          dev: dev.value,
          ino: ino.value,
          mode: Mode.new(mode.value),
          uid: uid.value,
          gid: gid.value,
          file_size: file_size.value,
          object_name: ObjectName.new(object_name.value),
          flags: Flags.new(flags.value),
          pathname: pathname.value
        )

        @entries << entry
      end


      #puts "Extentions"

      #i = 0
      #while (f.size > f.pos + 20)
        #puts "=== #{i}"
        #i += 1

        #signature = Stream::BinaryString.new(4)
        #size = Stream::Int32.new
        #stream >> signature >> size

        #p [signature.value, size.value]
        #p f.read(size.value)

        #if signature.value == "TREE"
          #left_to_read = size.value

          #while left_to_read > 0
            #path = TerminatedString.new("\0".b)
            #stream >> path

            #entry_count = TerminatedString.new(" ".b)
            #stream >> entry_count

            #subtrees_count = TerminatedString.new("\n".b)
            #stream >> subtrees_count

            #if entry_count.value != '-1'
              #object_name = BinaryString.new(20)
              #stream >> object_name

              #left_to_read -= path.value.size + 1 + entry_count.value.size + 1 + subtrees_count.value.size + 1 + object_name.value.size

              #p [path.value, entry_count.value, subtrees_count.value, object_name.hex]
            #else
              #left_to_read -= path.value.size + 1 + entry_count.value.size + 1 + subtrees_count.value.size + 1

              #p [path.value, entry_count.value, subtrees_count.value]
            #end
          #end
          ##p data.value
        #else
          #p [signature.value, size.value, data.value.inspect]
        #end
      #end

      #checksum = Stream::BinaryString.new(20)
      #stream >> checksum
      #puts "Checksum"
      #p checksum.value.bytes.map { |b| b.to_s(16) }.join

      #assert f.pos == f.size

    end

    class Entry
      attr_reader :ctime_seconds, :ctime_nanoseconds, :mtime_seconds, :mtime_nanoseconds,
        :dev, :ino, :mode, :uid, :gid, :file_size, :object_name, :flags, :pathname

      def initialize(ctime_seconds:, ctime_nanoseconds:, mtime_seconds:, mtime_nanoseconds:,
        dev:, ino:, mode:, uid:, gid:, file_size:, object_name:, flags:, pathname:)
        @ctime_seconds = ctime_seconds
        @ctime_nanoseconds = ctime_nanoseconds
        @mtime_seconds = mtime_seconds
        @mtime_nanoseconds = mtime_nanoseconds

        @dev = dev
        @ino = ino
        @mode = mode
        @uid = uid
        @gid = gid
        @file_size = file_size
        @object_name = object_name
        @flags = flags
        @pathname = pathname
      end
    end

    class ObjectName
      def initialize(string)
        @string = string
      end

      def hex
        @string.bytes.map { |b| "%02x" % b }.join
      end
    end

    class Flags
      def initialize(flags)
        @flags = flags
      end

      def stage_number
        (@flags >> 12) & 0b11
      end

      def pathname_size
         @flags & 0xFFF # 12 bits
      end

      def value
        @flags
      end
    end

    class Mode
      include Assert

      def initialize(mode)
        assert (mode >> 16) == 0
        assert ((mode >> 9) & 0b111) == 0

        @mode = mode
      end

      # valid values in binary are 1000 (regular file), 1010 (symbolic link) and 1110 (gitlink)
      def object_type
        (@mode >> 12) & 0b1111
      end

      # See object_type function in object.h
      def object_type_name
        case object_type
        when 0x4000     # OBJ_TREE
          "tree"
        when 0160000    # OBJ_COMMIT
          "commit"
        else            # OBJ_COMMIT
          "blob"
        end
      end

      # Only 0755 and 0644 are valid for regular files. Symbolic links and gitlinks have value 0 in this field.
      def unix_permissions
        @mode & 0b111111111
      end

      def value
        @mode
      end
    end
  end
end
