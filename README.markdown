README
======

Latex-renderer is a ruby library to generate images from latex code.

Usage
-----

Synchronous rendering:

    latex = LaTeX::Renderer.new(options)
    filename, filepath, hash = latex.render('\frac{1}{2}')

Asynchronous rendering:

    latex = LaTeX::AsyncRenderer.new(options)
    filename, filepath, hash = latex.render('\frac{1}{2}')
    ....
    filename, filepath, hash = latex.result(hash)

Options
-------

* image_dir: Target directory
* temp_dir:  Temporary directory
* convert_options: Options for imagemagick convert
* image_format: Target format
* debug: Debugging mode. Do not delete temporary files if an error occured
* service_uri: DRb service URI for asynchronous renderer

TODO
----

* Write unit tests or specs

Authors
-------

1. Original php latex renderer class by Benjamin Zeiss (http://www.mayer.dial.pipex.com/tex.htm)
2. Converted to ruby by Michael Petnuch
3. Cleanup by Phomb
4. Mostly rewritten and asynchronous renderer added by Daniel Mendler

License
-------

This library is released under LGPL version 3.
