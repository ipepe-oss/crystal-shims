require "./src/crystal-shims-http-server"

app = Crystal::Shims::HTTP::Server.new

# Simple route without parameters
app.route("GET", "/") do |context, params|
  "<h1>hello world</h1>"
end

# API endpoint without parameters
app.route("GET", "/api") do |context, params|
  {
    "message" => "Hello API",
    "version" => "1.0",
  }
end

# Route with explicit parameters - much cleaner!
app.route("GET", "/users/:id", ["id"]) do |context, params|
  "<h1>User Profile</h1><p>User ID: #{params["id"]}</p>"
end

# API with parameters
app.route("GET", "/api/users/:id", ["id"]) do |context, params|
  {
    "id"    => params["id"],
    "name"  => "User #{params["id"]}",
    "email" => "user#{params["id"]}@example.com",
  }
end

# Multiple parameters
app.route("POST", "/users/:id/posts/:post_id", ["id", "post_id"]) do |context, params|
  {
    "user_id" => params["id"],
    "post_id" => params["post_id"],
    "action"  => "created",
  }
end

# POST route without parameters
app.route("POST", "/submit") do |context, params|
  body = context.request.body.try(&.gets_to_end) || ""
  {
    "status" => "received",
    "body"   => body,
  }
end

# Custom content type removed for simplicity

puts "Server configured with routes:"

app.run("0.0.0.0", 8081)
