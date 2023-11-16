require_relative 'assert'

module DIYGit
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
  end
end
