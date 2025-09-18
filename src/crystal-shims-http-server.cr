require "http/server"
require "json"

<<<<<<< HEAD
module Crystal::Shims::HTTP
  alias Response = String | Hash(String, String)
  alias Handler = Proc(::HTTP::Server::Context, Hash(String, String), Response)

  record Route, method : String, path : String, handler : Handler, content_type : String? = nil do
    def matches?(req_method, req_path)
      @method == req_method && req_path.matches?(regex)
    end

    def extract_params(req_path)
      params = {} of String => String
      if match = req_path.match(regex)
        param_names.each_with_index { |name, i| params[name] = match[i + 1] }
      end
      params
    end

    private def regex
      @regex ||= Regex.new("^#{@path.gsub(/:(\w+)/) { "([^/]+)" }}$")
    end

    private def param_names
      @param_names ||= @path.scan(/:(\w+)/).map(&.[1])
    end

    @param_names : Array(String)?
  end

  class Router
    include ::HTTP::Handler
    getter routes = [] of Route

    {% for method in %w[get post put delete] %}
      def {{method.id}}(path, content_type = nil, &handler : Handler)
        @routes << Route.new("{{method.id.upcase}}", path.to_s, handler, content_type)
      end
    {% end %}

    def call(context)
      if route = @routes.find(&.matches?(context.request.method, context.request.path))
        params = route.extract_params(context.request.path)
        response = route.handler.call(context, params)
        context.response.content_type = route.content_type || (response.is_a?(Hash) ? "application/json" : "text/html")
        context.response.print(response.is_a?(Hash) ? response.to_json : response)
      else
        call_next(context)
      end
    end
  end

  class Server
    def initialize(@host = "0.0.0.0", @port = 8080, @router = Router.new)
    end

    def run
      server = ::HTTP::Server.new([
        ::HTTP::ErrorHandler.new,
        ::HTTP::LogHandler.new,
        ::HTTP::CompressHandler.new,
        @router,
        ::HTTP::StaticFileHandler.new("./public", fallthrough: true)
      ])

      puts "Listening on http://#{server.bind_tcp(@host, @port)}"
      server.listen
    end

    def get(path, content_type = nil, &handler : Handler)
      @router.get(path, content_type, &handler)
    end

    def post(path, content_type = nil, &handler : Handler)
      @router.post(path, content_type, &handler)
    end

    def put(path, content_type = nil, &handler : Handler)
      @router.put(path, content_type, &handler)
    end

    def delete(path, content_type = nil, &handler : Handler)
      @router.delete(path, content_type, &handler)
    end

    private def routes
      @router.routes
    end
  end
end

# Test server
app = Crystal::Shims::HTTP::Server.new("0.0.0.0", 8081)

app.get "/" { |_, _| "<h1>Hello World</h1>" }

app.get "/api" { |_, _| {"message" => "Hello API", "version" => "1.0"} }

app.get "/users/:id" { |_, params| "<h1>User #{params["id"]}</h1>" }

app.post "/submit" do |context, _|
  body = context.request.body.try(&.gets_to_end) || ""
  {"status" => "received", "body" => body}
end

app.run
=======
class Crystal::Shims::HTTP::Server
  include ::HTTP::Handler

  def initialize
    @routes = [] of {String, String, Array(String), Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String))}
  end

  def route(method, path, params = [] of String, &block : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
    @routes << {method.upcase, path, params, block}
  end

  def call(context)
    @routes.each do |method, path, param_names, handler|
      next unless context.request.method == method
      next unless extracted_params = extract_params(path, param_names, context.request.path)

      response = handler.call(context, extracted_params)
      context.response.content_type = response.is_a?(Hash) ? "application/json" : "text/html"
      context.response.print(response.is_a?(Hash) ? response.to_json : response.to_s)
      return
    end
    call_next(context)
  end

  def run(host = "0.0.0.0", port = 8080)
    server = ::HTTP::Server.new([
      ::HTTP::ErrorHandler.new,
      ::HTTP::LogHandler.new,
      ::HTTP::CompressHandler.new,
      self,
      ::HTTP::StaticFileHandler.new("./public", fallthrough: true, directory_listing: false),
    ])

    address = server.bind_tcp host, port
    puts "Listening on http://#{address}"
    server.listen
  end

  private def extract_params(path, param_names, request_path)
    path_segments = path.split('/')
    request_segments = request_path.split('/')
    return nil if path_segments.size != request_segments.size

    path_segments.each_with_index do |segment, i|
      return nil if segment.starts_with?(':') && !param_names.includes?(segment[1..-1])
      return nil if !segment.starts_with?(':') && segment != request_segments[i]
    end

    param_names.each_with_index.to_h { |name, i| {name, request_segments[path_segments.index(":#{name}").not_nil!]} }
  end
end
>>>>>>> @{-1}
