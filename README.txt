= README

Latex-renderer is a ruby library to generate images from latex code.

== Usage

Synchronous rendering:

 latex = Latex::Renderer.new(options)
 filename, filepath, hash = latex.render('\frac{1}{2}')

Asynchronous rendering:

 latex = Latex::AsyncRenderer.new(options)
 filename, filepath, hash = latex.render('\frac{1}{2}')
 ....
 filename, filepath, hash = latex.result(hash)

== Options

 * image_dir: Target directory
 * temp_dir:  Temporary directory
 * convert:   Options for imagemagick convert
 * image_format: Target format
 * debug: Debugging mode. Do not delete temporary files if an error occured

== TODO

 * write specs (There are no tests in test dir!)
