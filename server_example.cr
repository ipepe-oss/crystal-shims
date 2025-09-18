require "./src/crystal-shims-http-server"

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