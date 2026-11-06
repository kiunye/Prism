Prism.configure do
  connection :primary do |c|
    c.reuse_host_pool = true
    c.read_only_role = "prism_ro"
    c.default = true
  end

  self.owner_resolver = ->(_request) { { id: 1, type: "User" } }
  self.auth_guard = ->(_request) { true }
end
