require "http/server"
require "json"

struct Crystal::Shims::HTTP::Route
  getter method : String
  getter path : String
  getter handler : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String))
  getter content_type : String?

  def initialize(@method : String, @path : String, @content_type : String? = nil, &@handler : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
    @handler = handler
  end
end

class Crystal::Shims::HTTP::Router
  include ::HTTP::Handler

  @routes = {} of String => Hash(String, Route)

  def get(route, content_type : String? = nil, &block : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
    path = route.to_s
    @routes["GET"] ||= {} of String => Route
    @routes["GET"][path] = Route.new("GET", path, content_type, &block)
  end

  def post(route, content_type : String? = nil, &block : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
    path = route.to_s
    @routes["POST"] ||= {} of String => Route
    @routes["POST"][path] = Route.new("POST", path, content_type, &block)
  end

  def put(route, content_type : String? = nil, &block : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
    path = route.to_s
    @routes["PUT"] ||= {} of String => Route
    @routes["PUT"][path] = Route.new("PUT", path, content_type, &block)
  end

  def delete(route, content_type : String? = nil, &block : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
    path = route.to_s
    @routes["DELETE"] ||= {} of String => Route
    @routes["DELETE"][path] = Route.new("DELETE", path, content_type, &block)
  end

  def call(context)
    method = context.request.method
    path = context.request.path

    route, params = find_route(method, path)

    if route
      response = route.handler.call(context, params)

      # Auto-detect content type if not explicitly set
      if content_type = route.content_type
        context.response.content_type = content_type
      elsif response.is_a?(Hash)
        context.response.content_type = "application/json"
      else
        context.response.content_type = "text/html"
      end

      # Format response based on type
      if response.is_a?(Hash)
        context.response.print(response.to_json)
      else
        context.response.print(response.to_s)
      end
    else
      call_next(context)
    end
  end

  private def find_route(method : String, path : String) : {Route?, Hash(String, String)}
    # Try exact match first
    if method_routes = @routes[method]?
      if route = method_routes[path]?
        return {route, {} of String => String}
      end
    end

    # Try parameterized routes
    if method_routes = @routes[method]?
      method_routes.each do |route_path, route|
        if route_path.includes?(':')
          match_result = match_route(route_path, path)
          if match_result
            return {route, match_result}
          end
        end
      end
    end

    {nil, {} of String => String}
  end

  private def match_route(route_path : String, request_path : String) : Hash(String, String)?
    route_parts = route_path.split('/')
    request_parts = request_path.split('/')

    return nil if route_parts.size != request_parts.size

    params = {} of String => String

    route_parts.each_with_index do |route_part, i|
      if route_part.starts_with?(':')
        param_name = route_part[1..-1]
        params[param_name] = request_parts[i]
      elsif route_part != request_parts[i]
        return nil
      end
    end

    params
  end

  def routes
    result = [] of String
    @routes.each do |method, paths|
      paths.each do |path, _|
        result << "#{method} #{path}"
      end
    end
    result
  end
end

class Crystal::Shims::HTTP::Server
  @server : ::HTTP::Server?
  @host : String
  @port : Int32
  @router = Router.new

  def initialize(@host : String = "0.0.0.0", @port : Int32 = 8080)
  end

  def run
    @server = ::HTTP::Server.new([
      ::HTTP::ErrorHandler.new,
      ::HTTP::LogHandler.new,
      ::HTTP::CompressHandler.new,
      @router,
      ::HTTP::StaticFileHandler.new("./public", fallthrough: true, directory_listing: false),
    ])

    address = @server.not_nil!.bind_tcp @host, @port
    puts "Listening on http://#{address}"
    @server.not_nil!.listen
  end

  def stop
    if server = @server
      server.close
      puts "Server stopped"
    end
  end

  def get(route, content_type : String? = nil, &block : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
    @router.get(route, content_type, &block)
  end

  def post(route, content_type : String? = nil, &block : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
    @router.post(route, content_type, &block)
  end

  def put(route, content_type : String? = nil, &block : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
    @router.put(route, content_type, &block)
  end

  def delete(route, content_type : String? = nil, &block : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
    @router.delete(route, content_type, &block)
  end

  def routes
    @router.routes
  end
end

app = Crystal::Shims::HTTP::Server.new("0.0.0.0", 8081)

# String responses automatically get HTML content type
app.get "/" do |context, params|
  "<h1>hello world</h1>"
end

# Hash responses automatically get JSON content type
app.get "/api" do |context, params|
  {
    "message" => "Hello API",
    "version" => "1.0"
  }
end

# Route parameters with string response
app.get "/users/:id" do |context, params|
  "<h1>User Profile</h1><p>User ID: #{params["id"]}</p>"
end

# Route parameters with hash response
app.get "/api/users/:id" do |context, params|
  {
    "id"     => params["id"],
    "name"   => "User #{params["id"]}",
    "email"  => "user#{params["id"]}@example.com"
  }
end

# POST route with hash response
app.post "/submit" do |context, params|
  body = context.request.body.try(&.gets_to_end) || ""
  {
    "status" => "received",
    "body"   => body
  }
end

# Custom content type (overrides auto-detection)
app.get "/custom" do |context, params|
  {"custom" => "response"}.to_json
end

puts "Server configured with routes:"
app.routes.each { |route| puts "  #{route}" }

app.run
