# Checkend Elixir SDK

Elixir SDK for [Checkend](https://checkend.com) error monitoring. Async by default with Plug integration.

## Features

- **Async by default** - Non-blocking error sending via GenServer worker
- **Plug integration** - Easy integration with Phoenix and Plug apps
- **Automatic context** - Request, user, and custom context tracking
- **Sensitive data filtering** - Automatic scrubbing of passwords, tokens, etc.
- **Testing utilities** - Capture errors in tests without sending

## Installation

Add `checkend` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:checkend, "~> 1.0"}
  ]
end
```

## Quick Start

```elixir
# Configure the SDK (e.g., in application.ex or config.exs)
Checkend.configure(api_key: "your-api-key")

# Report an error
try do
  do_something()
rescue
  e -> Checkend.notify(e, __STACKTRACE__)
end
```

## Configuration

```elixir
Checkend.configure(
  api_key: "your-api-key",              # Required
  endpoint: "https://app.checkend.com",  # Optional: Custom endpoint
  environment: "production",             # Optional: Auto-detected
  enabled: true,                         # Optional: Enable/disable
  async_send: true,                      # Optional: Async sending (default: true)
  timeout: 15_000,                       # Optional: HTTP timeout in ms
  filter_keys: ["custom_secret"],        # Optional: Additional keys to filter
  ignored_exceptions: [MyError],         # Optional: Exceptions to ignore
  debug: false                           # Optional: Enable debug logging
)
```

### Environment Variables

```bash
CHECKEND_API_KEY=your-api-key
CHECKEND_ENDPOINT=https://your-server.com
CHECKEND_ENVIRONMENT=production
CHECKEND_DEBUG=true
```

## Manual Error Reporting

```elixir
# Basic error reporting
try do
  risky_operation()
rescue
  e -> Checkend.notify(e, __STACKTRACE__)
end

# With additional context
try do
  process_order(order_id)
rescue
  e ->
    Checkend.notify(e, __STACKTRACE__,
      context: %{order_id: order_id},
      user: %{id: user.id, email: user.email},
      tags: ["orders", "critical"],
      fingerprint: "order-processing-error"
    )
end

# Synchronous sending (blocks until sent)
{:ok, response} = Checkend.notify_sync(e, __STACKTRACE__)
IO.puts("Notice ID: #{response.id}")
```

## Context & User Tracking

```elixir
# Set context for all errors in this process
Checkend.set_context(%{
  order_id: 12345,
  feature_flag: "new-checkout"
})

# Set user information
Checkend.set_user(%{
  id: user.id,
  email: user.email,
  name: user.name
})

# Set request information
Checkend.set_request(%{
  url: conn.request_path,
  method: conn.method
})

# Clear all context (call at end of request)
Checkend.clear()
```

## Plug Integration

### With Phoenix

Add to your endpoint:

```elixir
# lib/my_app_web/endpoint.ex
plug Checkend.Plugs.ErrorHandler
```

### With Plug.ErrorHandler

```elixir
defmodule MyApp.Router do
  use Plug.Router
  use Plug.ErrorHandler

  # ... your routes ...

  defp handle_errors(conn, %{kind: kind, reason: reason, stack: stack}) do
    Checkend.Plugs.ErrorHandler.handle_error(conn, kind, reason, stack)
    send_resp(conn, 500, "Internal Server Error")
  end
end
```

## Testing

Use the `Testing` module to capture errors without sending them:

```elixir
defmodule MyTest do
  use ExUnit.Case

  setup do
    Checkend.Testing.setup()
    Checkend.configure(api_key: "test-key", enabled: true)

    on_exit(fn ->
      Checkend.reset()
    end)

    :ok
  end

  test "error reporting" do
    try do
      raise "Test error"
    rescue
      e -> Checkend.notify(e, __STACKTRACE__)
    end

    assert Checkend.Testing.has_notices?()
    assert Checkend.Testing.notice_count() == 1

    notice = Checkend.Testing.last_notice()
    assert notice.error_class == "RuntimeError"
  end
end
```

## Filtering Sensitive Data

By default, these keys are filtered: `password`, `secret`, `token`, `api_key`, `authorization`, `credit_card`, `cvv`, `ssn`, etc.

Add custom keys:

```elixir
Checkend.configure(
  api_key: "your-api-key",
  filter_keys: ["custom_secret", "internal_token"]
)
```

Filtered values appear as `[FILTERED]` in the dashboard.

## Ignoring Exceptions

```elixir
Checkend.configure(
  api_key: "your-api-key",
  ignored_exceptions: [
    Ecto.NoResultsError,
    Phoenix.Router.NoRouteError,
    ~r/.*NotFound.*/
  ]
)
```

## Before Notify Callbacks

```elixir
Checkend.configure(
  api_key: "your-api-key",
  before_notify: [
    fn notice ->
      # Add extra context
      %{notice | context: Map.put(notice.context, "server", node())}
    end,
    fn notice ->
      # Skip certain errors
      if String.contains?(notice.message, "ignore-me") do
        false
      else
        true
      end
    end
  ]
)
```

## Graceful Shutdown

The SDK automatically flushes pending notices on application shutdown. For manual control:

```elixir
# Wait for pending notices to send
Checkend.flush()

# Stop the worker
Checkend.stop()
```

## Requirements

- Elixir 1.14+
- OTP 25+

## Optional Dependencies

- `jason` - For JSON encoding (recommended)
- `plug` - For Plug integration

## Development

```bash
# Install dependencies
mix deps.get

# Run tests
mix test

# Format code
mix format
```

## License

MIT License - see [LICENSE](LICENSE) for details.

---

[Checkend](https://checkend.com) - Simple, powerful error monitoring for your applications.

Project sponsored by [Furvur](https://furvur.com).
