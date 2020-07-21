require "rubygems"
require "bundler/setup"
require "kramdown"
require "liquid"
require "nokogiri"
require "date"
require "securerandom"

# Utility

def normalize_html(html)
  html.each_line.inject("") do |html, line|
    if line.length != "\n"
      html += line.strip + "\n"
    end
  end
end

# Config

Liquid::Template.error_mode = :strict

# This whole file is very script-y: top to bottom, imperative,
# one thing after another

# First, get the basic info from the yaml

book_data = YAML.load(File.read("source/book.yaml"))

book_data["modified_date"] = DateTime.now.strftime("%Y-%m-%dT%H:%M:%SZ")
book_data["guid"] = SecureRandom.alphanumeric(12)

unless book_data["home_url"][-1] == "/"
  book_data["home_url"] += "/"
end

slug = book_data["slug"] # for convenience, because we will use it many times

# Build directory setup

if Dir.exist?("build")
  `rm -r build`
end

`mkdir build`
`mkdir build/web`
`mkdir build/epub`
`mkdir build/epub/BOOK`

# These files are annoying, so get rid of them

["source/img/.DS_Store",
 "source/font/.DS_Store",
 "source/img/.keep",
 "source/font/.keep"].each do |garbage_file|

  if File.exist?(garbage_file)
    `rm #{garbage_file}`
  end

end

# First, make the web book

print "Generating web book..."

web_book_build_path = "build/web"

book_body_markdown = File.read("source/#{book_data["markdown_source"]}")
book_body_html = Kramdown::Document.new(book_body_markdown).to_html

# Now, some tune-ups...

# 1. Widow remover (not perfect, but good)
book_body_html = book_body_html.gsub(/(\w+) (\w+[\.\!\?\"\”]+)\<\/p\>/,
                                     '\1&nbsp;\2</p>')

# 1a. Widow remover for links
book_body_html = book_body_html.gsub(/(\w+) (\w+)\<\/a\>/,
                                     '\1&nbsp;\2</a>')

# 2. Em dash fixer-upper
book_body_html = book_body_html.gsub(/(\w+)(—|&mdash;|&#8212;)([\"\”]?)/,
                                     '<span class="nobr">\1\2\3</span>')

# We need a logical map of the HTML to pull out the table of contents:

book = Nokogiri::HTML.fragment(book_body_html)

# And we are going to need a copy later, so might as well make it now

epub_book = book.clone

# Make the web TOC

# This variable holds the "logical TOC" we pull out of the markdown

toc_items = []
toc_duplicate_tracker = {}

# (Personally, I like treating the markdown as the "source of truth" and
# generating everything else from it.)

book.css("h2").each do |heading|
  # This is a version of the title suitable for use in an anchor tag:
  href_title = heading.inner_html.gsub(/\W/, "_").downcase

  if toc_duplicate_tracker[href_title]
    toc_duplicate_tracker[href_title] += 1
    href_title += "_#{toc_duplicate_tracker[href_title].to_s}"
  else
    toc_duplicate_tracker[href_title] = 1
  end

  # If the href has already been seen, add a count to the end
=begin
  if toc_items.collect { |item| item[:href_title] }.include? href_title
    puts "dup!"
    dups = toc_items.find_all do |item|
      item[:href_title].start_with? href_title
    end
    href_title = "#{href_title}-#{dups.length}"
  end
=end

  toc_items << {:title => heading.inner_html, :href_title => href_title}

  # Here, we make a clickable/bookmarkable chapter title...
  heading_link = book.document.create_element "a"
  heading_link.inner_html = heading.inner_html
  heading_link[:href] = "##{href_title}"

  new_heading = book.document.create_element "h2"
  new_heading[:id] = "chapter_" + href_title
  new_heading.add_child heading_link

  # ...and replace the chapter heading with that linkable version
  heading.replace new_heading
end

book_data["web_book_body_html"] = book.to_xhtml

# Now, we use our logical toc_items to generate actual an HTML TOC
# for the web book:
toc_chapters_html = toc_items.inject("") do |toc_html, toc_item|
  toc_html += "<li><a href=\"##{toc_item[:href_title]}\">#{toc_item[:title]}</a></li>";
end

book_data["web_toc_html"] = "<ol>" + toc_chapters_html + "</ol>"

# Now, we merge it all together

web_book_full_template = Liquid::Template.parse(File.read("source/_web-template/web-template.html"))

web_book_full_html = normalize_html( web_book_full_template.render( book_data ) )

File.write("#{web_book_build_path}/index.html", web_book_full_html)

# And finally, copy the static / uncompiled files

`mkdir #{web_book_build_path}/css`
`cp -r source/css/web.css #{web_book_build_path}/css/web-book-#{book_data["guid"]}.css`
`cp -r source/img #{web_book_build_path}`
`cp -r source/font #{web_book_build_path}`

print " done!\n"

# Onward to the epub

print "Generating epub..."

epub_build_path = "build/epub/BOOK"

# The epub's chapter headings don't need to be clikcable, but
# they do have to have the correct anchor names:

epub_book.css("h2").each do |heading|
  href_title = heading.inner_html.gsub(/\W/, "_").downcase
  heading[:id] = href_title
end

book_data["epub_book_body_html"] = epub_book.to_xhtml

# This is an epub thing; I hate computers
book_data["title_html"] = book_data["title_html"].gsub("&nbsp;", "&#160;")

# Let's prepare the data for the epub file manifest

# This is just a nice (?) way of automatically including all images in the img directory

ctr = 0

book_data["epub_image_manifest_xml"] = Dir["source/img/*"].inject("") do |image_html, image_path|
  ctr += 1
  image_path = image_path.gsub("source/", "")

  case image_path.split(".").last
  when "png"
    mime_type = "image/png"
  when "jpg"
    mime_type = "image/jpeg"
  when "jpeg"
    mime_type = "image/jpeg"
  end

  if image_path == book_data["cover_image"]
    extra_content = "properties=\"cover-image\" "
  else
    extra_content = ""
  end

  image_html += <<~HEREDOC
    <item id="img#{ctr}" href="#{image_path}" media-type="#{mime_type}" #{extra_content}/>
  HEREDOC
end

# Same idea, but for fonts

ctr = 0

book_data["epub_font_manifest_xml"] = Dir["source/font/*.woff2"].inject("") do |font_html, font_path|
  ctr += 1
  font_path = font_path.gsub("source/", "")
  font_html += <<~HEREDOC
    <item id="font#{ctr}" href="#{font_path}" media-type="font/woff2" />
  HEREDOC
end

# Now, as with the web book, we use the logical toc_items to generate actual
# HTML that we can insert into the epub:

book_data["epub_nav_items_html"] = toc_items.inject("") do |toc_html, toc_item|
  toc_html += <<~HEREDOC
    <li>
      <a href=\"#{slug}-content.xhtml##{toc_item[:href_title]}\">#{toc_item[:title]}</a>
    </li>
  HEREDOC
end

epub_nav_template = Liquid::Template.parse(File.read("source/_epub-template/nav-template.xhtml"))
epub_nav_html = normalize_html( epub_nav_template.render( book_data ) )

File.write("#{epub_build_path}/#{slug}-nav.xhtml", epub_nav_html)

# There's this additional TOC file you sometimes (?) need, so here we generate
# its HTML:

book_data["epub_nav_items_ncx"] = toc_items.inject("") do |toc_html, toc_item|
  toc_html += <<~HEREDOC
    <navPoint id="#{toc_item[:href_title]}">
      <navLabel>
        <text>#{toc_item[:title]}</text>
      </navLabel>
      <content src="#{slug}-content.xhtml##{toc_item[:href_title]}"/>
    </navPoint>
  HEREDOC
end

epub_ncx_template = Liquid::Template.parse(File.read("source/_epub-template/template.ncx"))
epub_ncx_html = normalize_html( epub_ncx_template.render( book_data ) )

File.write("#{epub_build_path}/toc.ncx", epub_ncx_html)

# Now we render out the actual book content

epub_content_template = Liquid::Template.parse(File.read("source/_epub-template/content-template.xhtml"))
epub_content_html = normalize_html( epub_content_template.render( book_data ) )

File.write("#{epub_build_path}/#{slug}-content.xhtml", epub_content_html)

# And the manifest

epub_opf_template = Liquid::Template.parse(File.read("source/_epub-template/template.opf"))
epub_opf_html = normalize_html( epub_opf_template.render( book_data ) )

File.write("#{epub_build_path}/book.opf", epub_opf_html)

# Copy over the static files

`cp -r source/css/epub.css #{epub_build_path}`
`cp -r source/img #{epub_build_path}`
`cp -r source/font #{epub_build_path}`

`cp -r source/_epub-template/META-INF build/epub`
`cp source/_epub-template/mimetype build/epub`

# And here we actually "create" the epub just by zipping up all these files
# Note the odd/annoying requirements for the mimetype file:
# 1. Must be first item in zip archive
# 2. Must be uncompressed

`cd build/epub;
 zip -X0 #{slug}.epub mimetype;
 zip -r -u #{slug}.epub META-INF BOOK`

print " done!\n"
