require 'digest'
require 'open4'
require 'fileutils'
require 'thread'

module Latex
  VERSION = '0.2'

  class Renderer
    def initialize(options = {})
      @options = {
        :image_dir         => '/tmp/latex-images',
        :temp_dir          => '/tmp/latex-images',
        :convert           => '-trim -density 120',
        :image_format      => 'png',
        :debug             => false
      }
      @options[:blacklist] = %w{
        include def command loop repeat open toks output input
        catcode name \\every \\errhelp \\errorstopmode \\scrollmode
        \\nonstopmode \\batchmode \\read \\write csname \\newhelp
        \\uppercase \\lowercase \\relax \\aftergroup \\afterassignment
        \\expandafter \\noexpand \\special $$
      }
      @options.update(options)
      
      FileUtils.mkdir_p(@options[:temp_dir], :mode => 0755)
      FileUtils.mkdir_p(@options[:image_dir], :mode => 0755)
    end

    def set(key, value)
      @option[key] = value
    end

    def render(formula)
      formula = process_formula(formula)
      hash = Digest::MD5.hexdigest(formula)

      file_name = hash + '.' + @options[:image_format]
      file_path = File.join(@options[:image_dir], file_name)
      if !File.exists?(file_path)
        generate(formula, hash)
      end

      [file_name, file_path, hash]
    end

    protected

    def generate(formula, hash)
      begin
        temp_dir = create_temp_dir(hash)
        latex2dvi(temp_dir, formula)
        dvi2ps(temp_dir)
        ps2image(temp_dir, hash)
      rescue
        FileUtils.rm_rf(temp_dir) if !@options[:debug]
      else
        FileUtils.rm_rf(temp_dir)
      end
    end

    def process_formula(formula)
      errors = @options[:blacklist].map do |cmd|
        formula.include?(cmd) ? cmd : nil
      end.compact
      errors.empty? || raise(ArgumentError.new(errors))

      formula.strip
    end

    def template(formula)
      <<END
\\documentclass{minimal}
\\usepackage[utf8]{inputenc}
\\usepackage{amsmath,amsfonts,amssymb}
\\usepackage{mathrsfs,esdiff,cancel}
\\usepackage[dvips,usenames]{color}
\\usepackage{nicefrac}
\\usepackage[fraction=nice]{siunitx}
\\usepackage{mathpazo}
\\begin{document}
$$
#{formula}
$$
\\end{document}
END
    end

    def create_temp_dir(hash)
      temp_dir = File.join(@options[:temp_dir], hash)
      FileUtils.mkdir_p(temp_dir)
      temp_dir
    end
    
    def sh(cmd, args)
      status = Open4.popen4("#{cmd} #{args}") do |pid, stdin, stdout, stderr|
        stdin.close
        stderr.read
        stdout.read
      end
      raise RuntimeError.new("Execution of #{cmd} failed with status #{status.exitstatus}") if status.exitstatus != 0
    end

    def latex2dvi(dir, formula)
      tex_file = File.join(dir, 'formula.tex')
      File.open(tex_file, 'w') {|f| f.write(template(formula)) }
      sh('latex', "--interaction=nonstopmode --output-directory=#{dir} #{tex_file}")
    end

    def dvi2ps(dir)
      file = File.join(dir, 'formula')
      sh('dvips', "-E #{file}.dvi -o #{file}.ps")
    end

    def ps2image(dir, hash)
      ps_file = File.join(dir, 'formula.ps')
      image_file = File.join(@options[:image_dir], "#{hash}.#{@options[:image_format]}")
      sh('convert', "#{@options[:convert]} #{ps_file} #{image_file}")
    end
  end

  class AsyncRenderer < Renderer
    def initialize(options = {})
      super(options)
      @queue = Queue.new
      @mutex = Mutex.new
      @jobs  = [] 
      @worker = nil
    end

    def result(hash)
      file_name = hash + '.' + @options[:image_format]
      file_path = File.join(@options[:image_dir], file_name)
      return [file_name, file_path, hash] if File.exists?(file_path)

      # Uhhh polling
      while @mutex.synchronize { @jobs.include?(hash) } do
        sleep 0.1
      end

      raise RuntimeError.new('LaTeX could not be generated') if !File.exists?(file_path)
      [file_name, file_path, hash]
    end

    protected

    def worker
      loop do
        formula, hash = @queue.pop

        begin
          sync_generate(formula, hash)
        rescue
        end

        @mutex.synchronize do
          @jobs.delete(hash)
          if @queue.empty?
            @worker = nil
            @mutex.unlock
            return
          end
        end

      end
    end

    alias sync_generate generate

    def generate(formula, hash)
      @mutex.synchronize {
        @queue << [formula, hash]
        @jobs << hash
        @worker = Thread.new { worker } if !@worker
      }
    end
  end

end

