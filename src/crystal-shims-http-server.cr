require "http/server"
require "json"

class Crystal::Shims::HTTP::Server
  include ::HTTP::Handler

  def initialize
    @routes = [] of {String, String, Array(String), String?, Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String))}
  end

  def route(method, path, params = [] of String, content_type = nil, &block : Proc(::HTTP::Server::Context, Hash(String, String), String | Hash(String, String)))
    @routes << {method.upcase, path, params, content_type, block}
  end

  def call(context)
    @routes.each do |method, path, param_names, content_type, handler|
      next unless context.request.method == method
      next unless extracted_params = extract_params(path, param_names, context.request.path)

      response = handler.call(context, extracted_params)
      context.response.content_type = content_type || (response.is_a?(Hash) ? "application/json" : "text/html")
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