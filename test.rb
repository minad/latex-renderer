require 'lib/latex_renderer'

latex = LatexRenderer.new

begin
  latex.render('1+1')
rescue Exception => ex
  puts ex.message
end
