require 'digest'
require 'open4'
require 'fileutils'

class LatexRenderer

  def initialize(options = {})
    @options = {
      :image_dir         => '/tmp/latex-images',
      :temp_dir          => '/tmp',
      :convert           => '-trim -density 100',
      :text_color        => 'black',
      :background_color  => 'white',
      :image_format      => 'png',
    }
    @options[:blacklist_commands] = %w{
      include def command loop repeat open toks output input
      catcode name \\every \\errhelp \\errorstopmode \\scrollmode
      \\nonstopmode \\batchmode \\read \\write csname \\newhelp
      \\uppercase \\lowercase \\relax \\aftergroup \\afterassignment
      \\expandafter \\noexpand \\special
    }
    @options.update(options)
  end

  def set(key, value)
    @option[key] = value
  end

  def render(formula)
    dup.process(formula)
  end

  protected

  def process(formula)
    @formula = formula
    check_formula

    @hash = Digest::SHA1.hexdigest(@formula)
    filename = @hash + '.' + @options[:image_format]
    filepath = File.join(@options[:image_dir], filename)
    if !File.exists?(filepath)
      begin
        create_temp_files
        latex_to_dvi
        dvi_to_ps
        ps_to_image
        FileUtils.mv @image_file, filepath
      ensure
        cleanup
      end
    end

    [filepath, @hash]
  end

  def template
<<END
\\documentclass{minimal}
\\usepackage[utf8]{inputenc}
\\usepackage{amsmath}
\\usepackage{amsfonts}
\\begin{document}
\\begin{gather*}
#{@formula}
\\end{gather*}
\\end{document}
END
  end

  def create_temp_files
    @tempdir = File.join(@options[:temp_dir], "#{@hash}-#{Thread.current.object_id.to_s(16)}")
    FileUtils.mkdir_p(@tempdir)
    @tex_file, @dvi_file, @ps_file, @image_file = ['tex', 'dvi', 'ps', @options[:image_format]].map do |e|
      File.join(@tempdir, 'tmp.' + e)
    end
  end

  def cleanup
    FileUtils.rm_rf(@tempdir)
  end

  def execute(command)
    puts command
    errors = ''
    status = Open4.popen4(command) do |pid, stdin, stdout, stderr|
      stdin.close
      errors = stdout.read + stderr.read
    end
    raise RuntimeError.new("Execution failed with status #{status.exitstatus}:\n#{errors}") if status.exitstatus != 0
  end

  def latex_to_dvi
    File.open(@tex_file, 'w') {|f| f.write template }
    execute("latex --interaction=nonstopmode --output-directory=#{@tempdir} #{@tex_file}")
  end

  def dvi_to_ps
    execute("dvips -E #{@dvi_file} -o #{@ps_file}")
  end

  def ps_to_image
    execute("convert #{@options[:convert]} #{@ps_file} #{@image_file}")
  end

  def check_formula
    errors = @options[:blacklist_commands].map do |cmd|
      @formula.include?(cmd) ? cmd : nil
    end.compact
    errors.empty? || raise(ArgumentError.new(errors))
  end
end

