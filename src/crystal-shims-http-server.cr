require "http/server"

class Crystal::Shims::HTTP::Server
  def initialize
    # allow @routes to save Proc as its value
    @routes = {} of String => (-> String)
  end

  def run
    server = ::HTTP::Server.new([
      ::HTTP::ErrorHandler.new,
      ::HTTP::LogHandler.new,
      ::HTTP::CompressHandler.new,
    ]) do |context|
      if @routes.has_key?(context.request.path.to_s)
        context.response.content_type = "text/html"
        context.response.print(@routes[context.request.path.to_s].call)
      else
        context.response.status_code = 404
      end
    end
    address = server.bind_tcp "0.0.0.0", 8080
    puts "Listening on http://#{address}"
    server.listen
  end

  # add method to dynamically add routes
  def get(route, &block : (-> String))
    @routes[route.to_s] = block
  end
end

app = Crystal::Shims::HTTP::Server.new

# the app will respond with the returned string
app.get "/" do
  "<h1>hello world</h1>"
end

# you can also exec code in block and return a string value
app.get "/app" do
  a = "hello"
  b = "app"
  "#{a} #{b}"
end

app.run
