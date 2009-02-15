require 'lib/latex_renderer'

latex = Latex::Renderer.new

begin
  latex.render('1+1')
rescue Exception => ex
  puts ex.message
end
