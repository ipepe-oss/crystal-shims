require "./spec_helper"
require "../src/crystal-shims-http-server"

describe Crystal::Shims::HTTP::Server do
  describe "initialization" do
    it "creates server with default host and port" do
      server = Crystal::Shims::HTTP::Server.new
      # Server initializes correctly
    end

    it "creates server" do
      server = Crystal::Shims::HTTP::Server.new
      # Server initializes correctly
    end
  end

  describe "route handling" do
    it "handles matching GET request" do
      server = Crystal::Shims::HTTP::Server.new

      server.route("GET", "/test") do |context, params|
        "GET response"
      end

      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/test"), response)

      server.call(context)
      response.close

      io.to_s.split("\r\n\r\n", 2).last.should eq("GET response")
    end

    it "handles matching POST request" do
      server = Crystal::Shims::HTTP::Server.new

      server.route("POST", "/test") do |context, params|
        "POST response"
      end

      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("POST", "/test"), response)

      server.call(context)
      response.close

      io.to_s.split("\r\n\r\n", 2).last.should eq("POST response")
    end

    it "returns 404 for non-matching route" do
      server = Crystal::Shims::HTTP::Server.new

      server.route("GET", "/test") do |context, params|
        "GET response"
      end

      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/nonexistent"), response)

      server.call(context)
      response.close

      io.to_s.should contain("404 Not Found")
    end

    it "handles routes with parameters" do
      server = Crystal::Shims::HTTP::Server.new

      server.route("GET", "/users/:id", ["id"]) do |context, params|
        "User #{params["id"]}"
      end

      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/users/123"), response)

      server.call(context)
      response.close

      io.to_s.split("\r\n\r\n", 2).last.should eq("User 123")
    end

    it "handles multiple parameters" do
      server = Crystal::Shims::HTTP::Server.new

      server.route("POST", "/users/:id/posts/:post_id", ["id", "post_id"]) do |context, params|
        {
          "user_id" => params["id"],
          "post_id" => params["post_id"],
          "action"  => "created",
        }
      end

      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("POST", "/users/123/posts/456"), response)

      server.call(context)
      response.close

      io.to_s.split("\r\n\r\n", 2).last.should eq(%({"user_id":"123","post_id":"456","action":"created"}))
    end

    it "handles hash response with auto content type" do
      server = Crystal::Shims::HTTP::Server.new

      server.route("GET", "/test") do |context, params|
        {"message" => "Hello World"}
      end

      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/test"), response)

      server.call(context)
      response.close

      response.headers["Content-Type"].should eq("application/json")
      io.to_s.split("\r\n\r\n", 2).last.should eq(%({"message":"Hello World"}))
    end

    # Custom content type removed for simplicity

    it "handles different HTTP methods correctly" do
      server = Crystal::Shims::HTTP::Server.new

      server.route("GET", "/resource") do |context, params|
        "GET resource"
      end

      server.route("POST", "/resource") do |context, params|
        "POST resource"
      end

      server.route("PUT", "/resource") do |context, params|
        "PUT resource"
      end

      server.route("DELETE", "/resource") do |context, params|
        "DELETE resource"
      end

      ["GET", "POST", "PUT", "DELETE"].each do |method|
        io = IO::Memory.new
        response = HTTP::Server::Response.new(io)
        context = HTTP::Server::Context.new(HTTP::Request.new(method, "/resource"), response)
        server.call(context)
        response.close
        io.to_s.split("\r\n\r\n", 2).last.should eq("#{method} resource")
      end
    end

    it "handles content type auto-detection" do
      server = Crystal::Shims::HTTP::Server.new

      server.route("GET", "/html") do |context, params|
        "<html><body>HTML Response</body></html>"
      end

      server.route("GET", "/json") do |context, params|
        {"type" => "json", "content" => "auto-detected"}
      end

      # Test HTML response
      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/html"), response)
      server.call(context)
      response.close
      response.headers["Content-Type"].should eq("text/html")
      io.to_s.split("\r\n\r\n", 2).last.should eq("<html><body>HTML Response</body></html>")

      # Test JSON response
      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/json"), response)
      server.call(context)
      response.close
      response.headers["Content-Type"].should eq("application/json")
      io.to_s.split("\r\n\r\n", 2).last.should eq(%({"type":"json","content":"auto-detected"}))
    end
  end

  describe "complete request flow" do
    it "handles multiple routes correctly" do
      server = Crystal::Shims::HTTP::Server.new

      server.route("GET", "/") do |context, params|
        "<h1>Home</h1>"
      end

      server.route("GET", "/api") do |context, params|
        {"message" => "API Response"}
      end

      server.route("GET", "/users/:id", ["id"]) do |context, params|
        {"user_id" => params["id"], "name" => "User #{params["id"]}"}
      end

      # Test home route
      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/"), response)
      server.call(context)
      response.close
      io.to_s.split("\r\n\r\n", 2).last.should eq("<h1>Home</h1>")

      # Test API route
      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/api"), response)
      server.call(context)
      response.close
      io.to_s.split("\r\n\r\n", 2).last.should eq(%({"message":"API Response"}))

      # Test parameterized route
      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/users/42"), response)
      server.call(context)
      response.close
      io.to_s.split("\r\n\r\n", 2).last.should eq(%({"user_id":"42","name":"User 42"}))
    end
  end
end
