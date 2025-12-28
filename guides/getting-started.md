# Getting Started with Checkend

[Checkend](https://checkend.com) is a simple, powerful error monitoring service for your applications. This guide will help you get the Checkend Elixir SDK up and running in minutes.

## Installation

Add `checkend` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:checkend, "~> 1.0"}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

## Configuration

### Basic Setup

Configure Checkend in your application startup or config:

```elixir
# In config/runtime.exs (recommended)
config :checkend,
  api_key: System.get_env("CHECKEND_API_KEY")

# Or configure at runtime
Checkend.configure(api_key: "your-api-key")
```

### Environment Variables

Checkend supports the following environment variables:

| Variable | Description |
|----------|-------------|
| `CHECKEND_API_KEY` | Your Checkend ingestion API key |
| `CHECKEND_ENDPOINT` | Custom API endpoint (optional) |
| `CHECKEND_ENVIRONMENT` | Environment name (auto-detected) |
| `CHECKEND_DEBUG` | Enable debug logging |

### Configuration Options

```elixir
Checkend.configure(
  api_key: "your-api-key",              # Required
  endpoint: "https://app.checkend.com", # API endpoint
  environment: "production",            # Environment name
  enabled: true,                        # Enable/disable reporting
  async_send: true,                     # Async sending (default)
  timeout: 15_000,                      # HTTP timeout in ms
  filter_keys: ["custom_secret"],       # Keys to filter
  ignored_exceptions: [MyApp.NotFound], # Exceptions to ignore
  debug: false                          # Debug logging
)
```

## Reporting Your First Error

### Basic Error Reporting

```elixir
try do
  risky_operation()
rescue
  e -> Checkend.notify(e, __STACKTRACE__)
end
```

### With Additional Context

```elixir
try do
  process_order(order_id)
rescue
  e ->
    Checkend.notify(e, __STACKTRACE__,
      context: %{order_id: order_id},
      user: %{id: user.id, email: user.email},
      tags: ["orders", "critical"]
    )
end
```

## Next Steps

- [Phoenix Integration](phoenix-integration.html) - Integrate with Phoenix applications
- [Testing Guide](testing.html) - Test error reporting in your test suite
- [API Documentation](Checkend.html) - Full API reference

---

*[Checkend](https://checkend.com) - Simple, powerful error monitoring. Project sponsored by [Furvur](https://furvur.com).*
