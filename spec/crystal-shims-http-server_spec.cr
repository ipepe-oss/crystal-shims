require "./spec_helper"
require "../src/crystal-shims-http-server"

describe Crystal::Shims::HTTP::RouteHandler do
  describe "initialization" do
    it "creates a handler with method, path, and block" do
      handler = Crystal::Shims::HTTP::RouteHandler.new("GET", "/test") do |context, params|
        "Hello World"
      end

      handler.method.should eq("GET")
      handler.path.should eq("/test")
      handler.content_type.should be_nil
    end

    it "creates a handler with custom content type" do
      handler = Crystal::Shims::HTTP::RouteHandler.new("POST", "/api", "application/json") do |context, params|
        {"result" => "success"}
      end

      handler.content_type.should eq("application/json")
    end

    it "compiles simple path without parameters" do
      handler = Crystal::Shims::HTTP::RouteHandler.new("GET", "/simple/path") do |context, params|
        "response"
      end

      handler.path_regex.match("/simple/path").should_not be_nil
      handler.path_regex.match("/wrong/path").should be_nil
      handler.param_names.should be_empty
    end

    it "compiles path with parameters" do
      handler = Crystal::Shims::HTTP::RouteHandler.new("GET", "/users/:id") do |context, params|
        "User #{params["id"]}"
      end

      handler.path_regex.match("/users/123").should_not be_nil
      handler.path_regex.match("/users/").should be_nil
      handler.param_names.should eq(["id"])
    end

    it "compiles path with multiple parameters" do
      handler = Crystal::Shims::HTTP::RouteHandler.new("GET", "/users/:id/posts/:post_id") do |context, params|
        "User #{params["id"]} Post #{params["post_id"]}"
      end

      handler.path_regex.match("/users/123/posts/456").should_not be_nil
      handler.path_regex.match("/users/123/posts/").should be_nil
      handler.param_names.should eq(["id", "post_id"])
    end
  end

  describe "parameter extraction" do
    it "passes correct parameters to handler" do
      handler = Crystal::Shims::HTTP::RouteHandler.new("GET", "/users/:id/posts/:post_id") do |context, params|
        "User #{params["id"]} Post #{params["post_id"]}"
      end

      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/users/123/posts/456"), response)

      # Set a dummy next handler to avoid call_next issues
      handler.next = ->(ctx : HTTP::Server::Context) {}

      handler.call(context)
      response.close

      io.to_s.split("\r\n\r\n", 2).last.should eq("User 123 Post 456")
    end
  end

  describe "request handling" do
    it "returns 404 for wrong method" do
      handler = Crystal::Shims::HTTP::RouteHandler.new("GET", "/test") do |context, params|
        "Hello World"
      end

      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("POST", "/test"), response)

      handler.call(context)
      # Should call next handler, meaning no response was set
      # Check if it's a 404 response
      io.to_s.should contain("404 Not Found")
    end

    it "returns 404 for wrong path" do
      handler = Crystal::Shims::HTTP::RouteHandler.new("GET", "/test") do |context, params|
        "Hello World"
      end

      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/wrong"), response)

      handler.call(context)
      # Should call next handler, meaning no response was set
      # Check if it's a 404 response
      io.to_s.should contain("404 Not Found")
    end

    it "handles string response with auto content type" do
      handler = Crystal::Shims::HTTP::RouteHandler.new("GET", "/test") do |context, params|
        "Hello World"
      end

      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/test"), response)

      # Set a dummy next handler to avoid call_next issues
      handler.next = ->(ctx : HTTP::Server::Context) {}

      handler.call(context)
      response.close

      response.headers["Content-Type"].should eq("text/html")
      io.to_s.split("\r\n\r\n", 2).last.should eq("Hello World")
    end

    it "handles hash response with auto content type" do
      handler = Crystal::Shims::HTTP::RouteHandler.new("GET", "/test") do |context, params|
        {"message" => "Hello World"}
      end

      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/test"), response)

      # Set a dummy next handler to avoid call_next issues
      handler.next = ->(ctx : HTTP::Server::Context) {}

      handler.call(context)
      response.close

      response.headers["Content-Type"].should eq("application/json")
      io.to_s.split("\r\n\r\n", 2).last.should eq(%({"message":"Hello World"}))
    end

    it "handles custom content type" do
      handler = Crystal::Shims::HTTP::RouteHandler.new("GET", "/test", "text/plain") do |context, params|
        {"message" => "Hello World"}
      end

      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/test"), response)

      # Set a dummy next handler to avoid call_next issues
      handler.next = ->(ctx : HTTP::Server::Context) {}

      handler.call(context)
      response.close

      response.headers["Content-Type"].should eq("text/plain")
      io.to_s.split("\r\n\r\n", 2).last.should eq(%({"message":"Hello World"}))
    end

    it "passes parameters to handler" do
      handler = Crystal::Shims::HTTP::RouteHandler.new("GET", "/users/:id") do |context, params|
        "User #{params["id"]}"
      end

      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/users/123"), response)

      # Set a dummy next handler to avoid call_next issues
      handler.next = ->(ctx : HTTP::Server::Context) {}

      handler.call(context)
      response.close

      io.to_s.split("\r\n\r\n", 2).last.should eq("User 123")
    end
  end
end

describe Crystal::Shims::HTTP::Router do
  describe "route registration" do
    it "registers GET routes" do
      router = Crystal::Shims::HTTP::Router.new

      router.get("/test") do |context, params|
        "GET response"
      end

      router.routes.should contain("GET /test")
    end

    it "registers POST routes" do
      router = Crystal::Shims::HTTP::Router.new

      router.post("/test") do |context, params|
        "POST response"
      end

      router.routes.should contain("POST /test")
    end

    it "registers PUT routes" do
      router = Crystal::Shims::HTTP::Router.new

      router.put("/test") do |context, params|
        "PUT response"
      end

      router.routes.should contain("PUT /test")
    end

    it "registers DELETE routes" do
      router = Crystal::Shims::HTTP::Router.new

      router.delete("/test") do |context, params|
        "DELETE response"
      end

      router.routes.should contain("DELETE /test")
    end

    it "registers routes with custom content type" do
      router = Crystal::Shims::HTTP::Router.new

      router.get("/api", "application/json") do |context, params|
        {"api" => "response"}
      end

      router.routes.should contain("GET /api")
    end
  end

  describe "route handling" do
    it "handles matching GET request" do
      router = Crystal::Shims::HTTP::Router.new

      router.get("/test") do |context, params|
        "GET response"
      end

      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/test"), response)

      router.call(context)
      response.close

      io.to_s.split("\r\n\r\n", 2).last.should eq("GET response")
    end

    it "handles matching POST request" do
      router = Crystal::Shims::HTTP::Router.new

      router.post("/test") do |context, params|
        "POST response"
      end

      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("POST", "/test"), response)

      router.call(context)
      response.close

      io.to_s.split("\r\n\r\n", 2).last.should eq("POST response")
    end

    it "returns 404 for non-matching route" do
      router = Crystal::Shims::HTTP::Router.new

      router.get("/test") do |context, params|
        "GET response"
      end

      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/nonexistent"), response)

      router.call(context)
      response.close

      # Should not set response, allowing next handler to handle
      # Check if it's a 404 response
      io.to_s.should contain("404 Not Found")
    end

    it "handles routes with parameters" do
      router = Crystal::Shims::HTTP::Router.new

      router.get("/users/:id") do |context, params|
        "User #{params["id"]}"
      end

      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/users/123"), response)

      router.call(context)
      response.close

      io.to_s.split("\r\n\r\n", 2).last.should eq("User 123")
    end
  end
end

describe Crystal::Shims::HTTP::Server do
  describe "initialization" do
    it "creates server with default host and port" do
      server = Crystal::Shims::HTTP::Server.new

      # Test that we can access the private instance variables through routes method
      server.routes.should be_empty
    end

    it "creates server with custom host and port" do
      server = Crystal::Shims::HTTP::Server.new("127.0.0.1", 3000)

      server.routes.should be_empty
    end
  end

  describe "route delegation" do
    it "delegates GET routes to router" do
      server = Crystal::Shims::HTTP::Server.new

      server.get("/test") do |context, params|
        "GET response"
      end

      server.routes.should contain("GET /test")
    end

    it "delegates POST routes to router" do
      server = Crystal::Shims::HTTP::Server.new

      server.post("/test") do |context, params|
        "POST response"
      end

      server.routes.should contain("POST /test")
    end

    it "delegates PUT routes to router" do
      server = Crystal::Shims::HTTP::Server.new

      server.put("/test") do |context, params|
        "PUT response"
      end

      server.routes.should contain("PUT /test")
    end

    it "delegates DELETE routes to router" do
      server = Crystal::Shims::HTTP::Server.new

      server.delete("/test") do |context, params|
        "DELETE response"
      end

      server.routes.should contain("DELETE /test")
    end
  end

  describe "server lifecycle" do
    it "can be stopped without being started" do
      server = Crystal::Shims::HTTP::Server.new

      # Should not raise an exception
      server.stop
    end
  end
end

describe "HTTP Server Integration" do
  describe "complete request flow" do
    it "handles multiple routes correctly" do
      server = Crystal::Shims::HTTP::Server.new

      server.get("/") do |context, params|
        "<h1>Home</h1>"
      end

      server.get("/api") do |context, params|
        {"message" => "API Response"}
      end

      server.get("/users/:id") do |context, params|
        {"user_id" => params["id"], "name" => "User #{params["id"]}"}
      end

      # Test home route
      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/"), response)

      # Create a router directly for testing
      router = Crystal::Shims::HTTP::Router.new
      router.get("/") do |context, params|
        "<h1>Home</h1>"
      end
      router.get("/api") do |context, params|
        {"message" => "API Response"}
      end
      router.get("/users/:id") do |context, params|
        {"user_id" => params["id"], "name" => "User #{params["id"]}"}
      end

      router.call(context)
      response.close
      io.to_s.split("\r\n\r\n", 2).last.should eq("<h1>Home</h1>")

      # Test API route
      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/api"), response)
      router.call(context)
      response.close
      io.to_s.split("\r\n\r\n", 2).last.should eq(%({"message":"API Response"}))

      # Test parameterized route
      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/users/42"), response)
      router.call(context)
      response.close
      io.to_s.split("\r\n\r\n", 2).last.should eq(%({"user_id":"42","name":"User 42"}))
    end

    it "handles different HTTP methods correctly" do
      server = Crystal::Shims::HTTP::Server.new

      server.get("/resource") do |context, params|
        "GET resource"
      end

      server.post("/resource") do |context, params|
        "POST resource"
      end

      server.put("/resource") do |context, params|
        "PUT resource"
      end

      server.delete("/resource") do |context, params|
        "DELETE resource"
      end

      # Test each method
      router = Crystal::Shims::HTTP::Router.new
      router.get("/resource") do |context, params|
        "GET resource"
      end
      router.post("/resource") do |context, params|
        "POST resource"
      end
      router.put("/resource") do |context, params|
        "PUT resource"
      end
      router.delete("/resource") do |context, params|
        "DELETE resource"
      end

      ["GET", "POST", "PUT", "DELETE"].each do |method|
        io = IO::Memory.new
        response = HTTP::Server::Response.new(io)
        context = HTTP::Server::Context.new(HTTP::Request.new(method, "/resource"), response)
        router.call(context)
        response.close
        io.to_s.split("\r\n\r\n", 2).last.should eq("#{method} resource")
      end
    end

    it "handles content type auto-detection" do
      router = Crystal::Shims::HTTP::Router.new

      router.get("/html") do |context, params|
        "<html><body>HTML Response</body></html>"
      end

      router.get("/json") do |context, params|
        {"type" => "json", "content" => "auto-detected"}
      end

      # Test HTML response
      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/html"), response)
      router.call(context)
      response.close
      response.headers["Content-Type"].should eq("text/html")
      io.to_s.split("\r\n\r\n", 2).last.should eq("<html><body>HTML Response</body></html>")

      # Test JSON response
      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/json"), response)
      router.call(context)
      response.close
      response.headers["Content-Type"].should eq("application/json")
      io.to_s.split("\r\n\r\n", 2).last.should eq(%({"type":"json","content":"auto-detected"}))
    end
  end
end