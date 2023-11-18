module DIYGit
  # Resources
  # - https://git-scm.com/docs/git-ls-files

  # Example:
  #   ctime: 1700006171:904044119
  #   mtime: 1700006171:881566492
  #   dev: 16777220	ino: 180056853
  #   uid: 501	gid: 20
  #   size: 5949	flags: 0
  class CacheEntryDebugInfo
    def initialize(entry)
      @entry = entry
    end

    def report
      [
        "  ctime: %d:%d" % [@entry.ctime_seconds, @entry.ctime_nanoseconds],
        "  mtime: %d:%d" % [@entry.mtime_seconds, @entry.mtime_nanoseconds],
        "  dev: %d\tino: %d" % [@entry.dev, @entry.ino],
        "  uid: %d\tgid: %d" % [@entry.uid, @entry.gid],
        "  size: %d\tflags: %d" % [@entry.file_size, @entry.flags.value],
      ].join("\n")
    end
  end
end
