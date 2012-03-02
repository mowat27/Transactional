module Transactional
  class FileSystem
    def initialize(root)
      @root = root
      @tfiles = []
    end

    def open(rpath)
      @tfiles << TFile.load(@root, rpath)
      @tfiles.last.open {|f| yield f if block_given?}
    end

    def rollback
      @tfiles.each {|tfile| tfile.rollback}
    end
  end

  class TFile
    def self.load(root, rpath)
      target = File.join(root, rpath)
      if File.exists? target
        ExistingTFile.new(target)
      else
        NewTFile.new(target)
      end
    end

    private
    def initialize(path)
      @path = path
    end

    public
    def open(opts = {mode: "w"}, &block)
      File.open(@path, opts, &block)
    end
  end

  class NewTFile < TFile
    def rollback
      FileUtils.rm @path if File.exists? @path
    end
  end

  class ExistingTFile < TFile
    def initialize(path)
      super
      @original_data = File.read(@path)
    end

    def rollback
      open {|f| f.print @original_data}
    end
  end

  class Transaction
    def initialize
      @filesystems = []
    end

    def rollback
      @filesystems.each {|filesystem| filesystem.rollback}
    end

    def create_file_system(filesystem_root)
      result = FileSystem.new(filesystem_root)
      @filesystems << result
      result
    end
  end

  def self.start_transaction
    yield Transaction.new
  end
end