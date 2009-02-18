require 'lib/latex-renderer'

hashes = []
latex = Latex::AsyncRenderer.new


3.times do |i| 
  formula = (rand*1e10).round.to_s
  name,path,hash = latex.render(formula)
  hashes << hash
end
hashes.each do |hash|
  latex.result(hash)
end
sleep 6
3.times do |i| 
  formula = (rand*1e10).round.to_s
  name,path,hash = latex.render(formula)
  hashes << hash
end

hashes.each do |hash|
  latex.result(hash)
end
