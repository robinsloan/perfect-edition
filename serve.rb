require "webrick"
require "listen"

template_listener = Listen.to("source/", {wait_for_delay: 2}) do |modified, added, removed|
  modified.each do |filename|
    puts `ruby generate.rb`
  end
end

template_listener.start

port = ARGV[0] || 8000

class NonCachingFileHandler < WEBrick::HTTPServlet::FileHandler
  def prevent_caching(res)
    res['ETag']          = nil
    res['Last-Modified'] = Time.now + 100**4
    res['Cache-Control'] = "no-store, no-cache, must-revalidate, post-check=0, pre-check=0"
    res['Pragma']        = "no-cache"
    res['Expires']       = Time.now - 100**4
  end

  def set_access
    @response.headers["Access-Control-Allow-Origin"] = "*"
  end

  def do_GET(req, res)
    super
    prevent_caching(res)
  end
end

unless Dir.exist?("build")
  `ruby generate.rb`
end

server = WEBrick::HTTPServer.new :Port => port
server.mount "/", NonCachingFileHandler , Dir.pwd + "/build/web"
trap("INT") { server.stop }
server.start