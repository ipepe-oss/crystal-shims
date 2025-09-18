require "http/server"
require "json"

class Crystal::Shims::HTTP::RouteHandler
  include ::HTTP::Handler

  getter method : String
  getter path : String
  getter param_names : Array(String)
  getter handler : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String))
  getter content_type : String?

  def initialize(method : String, path : String, params : Array(String) = [] of String, content_type : String? = nil, &@handler : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
    @method = method
    @path = path
    @content_type = content_type
    @param_names = params
  end

  def call(context)
    return call_next(context) unless context.request.method == @method

    params = extract_params(context.request.path)
    return call_next(context) unless params

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

  private def extract_params(request_path : String) : Hash(String, String)?
    # Simple path matching: split both paths and compare segments
    path_segments = @path.split('/')
    request_segments = request_path.split('/')

    return nil if path_segments.size != request_segments.size

    params = {} of String => String

    path_segments.each_with_index do |segment, i|
      if segment.starts_with?(':')
        param_name = segment[1..-1]
        if @param_names.includes?(param_name)
          params[param_name] = request_segments[i]
        else
          return nil # Unknown parameter
        end
      elsif segment != request_segments[i]
        return nil # Path mismatch
      end
    end

    params
  end
end

class Crystal::Shims::HTTP::Router
  include ::HTTP::Handler

  @handlers = [] of RouteHandler
  @next_handler : ::HTTP::Handler? = nil

  def route(method : String, path : String, params : Array(String) = [] of String, content_type : String? = nil, &block : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
    @handlers << RouteHandler.new(method.upcase, path, params, content_type, &block)
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

  def route(method : String, path : String, params : Array(String) = [] of String, content_type : String? = nil, &block : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
    @router.route(method, path, params, content_type, &block)
  end

  def routes
    @router.routes
  end
end

# Server initialization code moved to example file to avoid interfering with specs
# See server_example.cr for usage example
