require "http/server"
require "json"

class Crystal::Shims::HTTP::RouteHandler
  include ::HTTP::Handler

  getter method : String
  getter path : String
  getter path_regex : Regex
  getter param_names : Array(String)
  getter handler : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String))
  getter content_type : String?

  def initialize(method : String, path : String, content_type : String? = nil, &@handler : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
    @method = method
    @path = path
    @content_type = content_type
    @path_regex, @param_names = compile_path(path)
  end

  def call(context)
    return call_next(context) unless context.request.method == @method

    match = @path_regex.match(context.request.path)
    return call_next(context) unless match

    params = extract_params(match, @param_names)
    response = @handler.call(context, params)

    # Auto-detect content type if not explicitly set
    if content_type = @content_type
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
  end

  private def compile_path(path : String) : {Regex, Array(String)}
    param_names = [] of String
    return {Regex.new("^\\#{path}$"), param_names} unless path.includes?(':')

    pattern = path.gsub(/:([a-zA-Z_][a-zA-Z0-9_]*)/) do |match|
      param_names << match[1..-1]
      "([^/]+)"
    end

    {Regex.new("^\\#{pattern}$"), param_names}
  end

  private def extract_params(match : Regex::MatchData, param_names : Array(String)) : Hash(String, String)
    params = {} of String => String
    param_names.each_with_index do |name, i|
      params[name] = match[i + 1]
    end
    params
  end
end

class Crystal::Shims::HTTP::Router
  include ::HTTP::Handler

  @handlers = [] of RouteHandler
  @next_handler : ::HTTP::Handler? = nil

  def get(route, content_type : String? = nil, &block : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
    @handlers << RouteHandler.new("GET", route.to_s, content_type, &block)
  end

  def post(route, content_type : String? = nil, &block : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
    @handlers << RouteHandler.new("POST", route.to_s, content_type, &block)
  end

  def put(route, content_type : String? = nil, &block : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
    @handlers << RouteHandler.new("PUT", route.to_s, content_type, &block)
  end

  def delete(route, content_type : String? = nil, &block : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
    @handlers << RouteHandler.new("DELETE", route.to_s, content_type, &block)
  end

  def call(context)
    # Set up the handler chain
    current_handler = @next_handler
    @handlers.reverse_each do |handler|
      handler.next = current_handler
      current_handler = handler
    end

    # Start the chain or call next if no handlers
    if current_handler
      current_handler.call(context)
    else
      call_next(context)
    end
  end

  def routes
    @handlers.map { |handler| "#{handler.method} #{handler.path}" }
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

# Server initialization code moved to example file to avoid interfering with specs
# See server_example.cr for usage example
