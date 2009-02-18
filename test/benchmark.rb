require 'rubygems'
require 'benchmark'
require 'lib/latex-renderer'

hashes = []
sync_latex = Latex::Renderer.new
async_latex = Latex::AsyncRenderer.new

Benchmark.bm do |x|
  x.report 'sync    ' do
    (1..10).each do |i|
      name,path,hash = sync_latex.render("sync#{i}")
    end
  end
  x.report 'async #1' do
    (1..10).each do |i|
      name,path,hash = async_latex.render("async#{i}")
      hashes << hash
    end
  end
  x.report 'async #2' do
    hashes.each do |hash|
      async_latex.result(hash)
    end
  end
end
