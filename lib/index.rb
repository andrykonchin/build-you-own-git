# Resources
# - https://github.com/git/git/blob/master/Documentation/gitformat-index.txt

module DIYGit
  class Index
    module Assert
      def assert(actual, message = nil)
        if !actual
          raise "Assert failed (#{message})"
        end
      end
    end

    include Assert

    class Stream
      include Assert

      def initialize(io)
        @io = io
      end

      def >>(target)
        if target.respond_to?(:bytesize)
          bytes = @io.read(target.bytesize)
          assert target.bytesize == bytes.size, "expected #{target.bytesize} == #{bytes.size}"

          target.assign(bytes)
        elsif target.respond_to?(:terminator)
          while (char = @io.getc) != target.terminator
            assert char != nil

            target.append(char)
          end
        else
          raise "unexpected target #{target}"
        end

        self
      end
    end

    class Int32
      include Assert

      def bytesize
        4
      end

      def assign(string)
        @value = string.unpack1("N")
      end

      def value
        assert !@value.nil?

        @value
      end
    end

    class Int16
      include Assert

      def bytesize
        2
      end

      def assign(string)
        @value = string.unpack1("n")
      end

      def value
        assert !@value.nil?

        @value
      end
    end

    class BinaryString
      include Assert
      attr_reader :bytesize

      def initialize(bytesize)
        @bytesize = bytesize
      end

      def assign(string)
        @value = string
      end

      def value
        assert !@value.nil?

        @value
      end

      def hex
        @value.bytes.map { |b| b.to_s(16) }.join
      end
    end

    class TerminatedString
      attr_reader :terminator, :value

      def initialize(terminator)
        @terminator = terminator
        @value = ""
      end

      def append(char)
        @value.concat(char)
      end
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

    attr_reader :workdir, :entries, :signature, :version, :entries_number

    def initialize(workdir)
      @workdir = workdir
      @entries = []
    end

    def parse
      f = File.open(@workdir + '/.git/index', encoding: 'binary')
      stream = Stream.new(f)

      signature = BinaryString.new(4)
      version, entries_number = Int32.new, Int32.new

      stream >> signature >> version >> entries_number # => ["DIRC", 2, 13430]
      @signature = signature.value
      @version = version.value
      @entries_number = entries_number.value

      #puts "header"
      #p [signature.value, version.value, entries_number.value]

      entries_number.value.times do
        ctime_seconds, ctime_nanoseconds, mtime_seconds, mtime_nanoseconds, dev, ino, mode, uid, gid, file_size = Int32.new, Int32.new, Int32.new, Int32.new, Int32.new, Int32.new, Int32.new, Int32.new, Int32.new, Int32.new
        object_name = BinaryString.new(20)
        flags = Int16.new

        stream >> ctime_seconds >> ctime_nanoseconds >> mtime_seconds >> mtime_nanoseconds >> dev >> ino >> mode >> uid >> gid >> file_size
        stream >> object_name
        stream >> flags

        unused = mode.value >> 16 # must == 0
        object_type = mode.value >> 12 # valid values in binary are 1000 (regular file), 1010 (symbolic link) and 1110 (gitlink)
        unused2 = (mode.value >> 9) & 0b111 # must == 0
        unix_permissions = mode.value & 0b111111111 # Only 0755 and 0644 are valid for regular files. Symbolic links and gitlinks have value 0 in this field.

        pathname_size = Flags.new(flags.value).pathname_size
        padding_size = (8 - (62 + pathname_size + 1) % 8) % 8

        pathname = BinaryString.new(pathname_size)
        padding = BinaryString.new(padding_size + 1) # pathname ending \0 + padding \0's
        stream >> pathname >> padding

        #puts "entry"
        #p [unused, object_type.to_s(2), unused2, unix_permissions.to_s(8), uid.value, gid.value, file_size.value, object_name.hex, "%016b" % flags.value, pathname.value]
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

      def object_name_shortest_uniq_prefix_length
        assert !@entries.nil?

        tie = {}

        #@entries.each do |entry|
        entries = ["abc_", "abd_", "a12_"]
        p entries
        entries.each do |entry|
          children = tie

          #entry.object_name.hex.each_char do |c|
          entry.each_char do |c|
            if children[c].nil?
              children[c] = {count: 0, children: {}}
            end

            children[c][:count] += 1
            children = children[c][:children]
          end
        end
        pp tie

        length = 1
        nodes = tie.values

        while !nodes.empty?
          p nodes
          p nodes.map { |n| n[:count] }
          if nodes.all? { |n| n[:count] == 1 }
            return length
          end

          nodes = nodes.map { |n| n[:children].values }.flatten
          length += 1
        end

        20
      end

      #puts "Extentions"

      #i = 0
      #while (f.size > f.pos + 20)
        #puts "=== #{i}"
        #i += 1

        #signature = BinaryString.new(4)
        #size = Int32.new
        #stream >> signature >> size

        #p [signature.value, size.value]

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

      #checksum = BinaryString.new(20)
      #stream >> checksum
      #puts "Checksum"
      #p checksum.value.bytes.map { |b| b.to_s(16) }.join

      #assert f.pos == f.size

    end
  end
end
