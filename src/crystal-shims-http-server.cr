require "http/server"
require "json"

class Crystal::Shims::HTTP::RouteHandler
  include ::HTTP::Handler

  getter method, path, param_names, content_type

  def initialize(@method : String, @path : String, @param_names : Array(String) = [] of String, @content_type : String? = nil, &@handler : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
  end

  def call(context)
    return false unless context.request.method == @method
    return false unless params = extract_params(context.request.path)

    response = @handler.call(context, params)

    context.response.content_type = @content_type || (response.is_a?(Hash) ? "application/json" : "text/html")
    context.response.print(response.is_a?(Hash) ? response.to_json : response.to_s)
    true
  end

  private def extract_params(request_path)
    path_segments = @path.split('/')
    request_segments = request_path.split('/')
    return nil if path_segments.size != request_segments.size

    path_segments.each_with_index do |segment, i|
      return nil if segment.starts_with?(':') && !@param_names.includes?(segment[1..-1])
      return nil if !segment.starts_with?(':') && segment != request_segments[i]
    end

    @param_names.each_with_index.to_h { |name, i| {name, request_segments[path_segments.index(":#{name}").not_nil!]} }
  end
end

class Crystal::Shims::HTTP::Router
  include ::HTTP::Handler

  def initialize
    @handlers = [] of RouteHandler
  end

  def route(method, path, params = [] of String, content_type = nil, &block : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
    @handlers << RouteHandler.new(method.upcase, path, params, content_type, &block)
  end

  def call(context)
    @handlers.each do |handler|
      return if handler.call(context)
    end
    call_next(context)
  end

  def routes
    @handlers.map { |h| "#{h.method} #{h.path}" }
  end
end

class Crystal::Shims::HTTP::Server
  def initialize(@host = "0.0.0.0", @port = 8080)
    @router = Router.new
  end

  def route(method, path, params = [] of String, content_type = nil, &block : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
    @router.route(method, path, params, content_type, &block)
  end

  def run
    server = ::HTTP::Server.new([
      ::HTTP::ErrorHandler.new,
      ::HTTP::LogHandler.new,
      ::HTTP::CompressHandler.new,
      @router,
      ::HTTP::StaticFileHandler.new("./public", fallthrough: true, directory_listing: false),
    ])

    address = server.bind_tcp @host, @port
    puts "Listening on http://#{address}"
    server.listen
  end
end
