require 'digest'
require 'rubygems'
require 'fileutils'
require 'thread'
require 'monitor'
require 'drb'

module LaTeX
  VERSION = '0.3.1'

  # Basic synchronous renderer class
  class Renderer

    # Initialize renderer with option hash
    def initialize(options = {})
      @options = {
        :image_dir         => '/tmp/latex-images',
        :temp_dir          => '/tmp/latex-images',
        :convert_options   => '-trim -density 120',
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

    # Set rendering option
    def set(key, value)
      @option[key] = value
    end

    # Render formula.
    # Returns [file_name, file_path, hash]
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

    private
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
        errors = @options[:blacklist].select do |cmd|
          formula.include?(cmd)
        end
        errors.empty? || raise(ArgumentError.new("Invalid latex commands #{errors.join(', ')}"))
        formula.strip
      end

      def template(formula)
        <<END # {{{
\\documentclass{minimal}
\\newcommand\\use[2][]{\\IfFileExists{#2.sty}{\\usepackage[#1]{#2}}{}}
\\use[utf8]{inputenc}
\\use{amsmath}
\\use{amsfonts}
\\use{amssymb}
\\use{mathrsfs}
\\use{esdiff}
\\use{cancel}
\\use[dvips,usenames]{color}
\\use{nicefrac}
\\use[fraction=nice]{siunitx}
\\use{mathpazo}
\\begin{document}
$$
#{formula}
$$
\\end{document}
END
        # }}}
      end

      def create_temp_dir(hash)
        temp_dir = File.join(@options[:temp_dir], hash)
        FileUtils.mkdir_p(temp_dir)
        temp_dir
      end

      def sh(cmd, args)
        `#{cmd} #{args} 2>&1 > /dev/null`
	raise RuntimeError.new("Execution of #{cmd} failed with status #{$?}") if $? != 0
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
        sh('convert', "#{@options[:convert_options]} #{ps_file} #{image_file}")
      end
end

# Asynchronous renderer that uses DRb to communicate with a background worker
class AsyncRenderer < Renderer
  def initialize(options = {})
    super(options)
    @options[:service_uri] ||= 'drbunix:///tmp/latex-renderer.sock'
  end

  # Get rendering result by hash
  def result(hash)
    file_name = hash + '.' + @options[:image_format]
    file_path = File.join(@options[:image_dir], file_name)
    return [file_name, file_path, hash] if File.exists?(file_path)

    # Uhhh polling
    while worker.enqueued?(hash) do
      sleep 0.1
    end

    raise RuntimeError.new('LaTeX could not be generated') if !File.exists?(file_path)
    [file_name, file_path, hash]
  end

  protected
    def worker
      begin
        worker = DRb::DRbObject.new(nil, @options[:service_uri])
        worker.respond_to? :enqueue
        worker
      rescue
        Worker.new(@options[:service_uri], @@generate.bind(self))
        DRb::DRbObject.new(nil, @options[:service_uri])
      end
    end

    @@generate = instance_method(:generate)

    def generate(formula, hash)
      5.times do
        begin
	  worker.enqueue(formula, hash)
          return
	rescue
	  sleep 0.5
	  next
	end
      end
    end

    class Worker
      def initialize(service, proc)
        @queue = []
        @queue.extend(MonitorMixin)
        @empty = @queue.new_cond
        @proc = proc
        Thread.new do
          @server = DRb.start_service(service, self)
          run
        end
      end

      def enqueue(formula, hash)
        @queue.synchronize do
          @queue << [formula, hash]
          @empty.signal
        end
      end

      def enqueued?(hash)
        @queue.synchronize do
          @queue.any? {|x| x[1] == hash }
        end
      end

      private

        def wait_while_empty
          while @queue.empty?
            if !@empty.wait(5)
              @server.stop_service
              DRb.primary_server = nil if DRb.primary_server == @server
              @server = nil
              return false
            end
          end
          true
        end

        def run
          loop do
            formula, hash = @queue.synchronize do
              return if !wait_while_empty
              @queue.first
            end
            @proc[formula, hash] rescue nil
            @queue.synchronize do
              @queue.shift
            end
          end
        end
    end
  end
end
Latex = LaTeX
# vim: foldmethod=marker
