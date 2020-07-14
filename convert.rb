require "shellwords"

# /Applications/calibre.app/Contents/MacOS/ebook-convert build/annabel-scheme-new-golden-gate/epub/annabel-scheme-new-golden-gate.epub annabel-scheme.azw3

Dir["build/*"].each do |dir|

  Dir["#{dir}/epub/*epub"].each do |epub|
    basename = epub.split("/").last
    puts "Converting #{basename} to PDF"

    pdf_name = epub.gsub(".epub", ".pdf")
    `/Applications/calibre.app/Contents/MacOS/ebook-convert #{Shellwords.escape(epub)} #{Shellwords.escape(pdf_name)}`

    puts "Converting #{basename} to mobi"

    # Note: kindlegen doesn't want a path with the output filename
    mobi_name = epub.split("/").last.gsub(".epub", ".mobi")
    `./kindlegen #{Shellwords.escape(epub)} -c0 -verbose -o #{Shellwords.escape(mobi_name)}`

  end
end