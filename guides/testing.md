# Testing Guide

This guide covers testing error reporting with the [Checkend](https://checkend.com) Elixir SDK. The SDK provides a `Checkend.Testing` module that captures errors locally instead of sending them to the API.

## Basic Setup

### Enable Testing Mode

In your test setup, enable testing mode to capture errors locally:

```elixir
defmodule MyApp.ErrorReportingTest do
  use ExUnit.Case

  setup do
    # Enable testing mode - errors are captured, not sent
    Checkend.Testing.setup()

    # Configure with a test key
    Checkend.configure(api_key: "test-key", enabled: true)

    on_exit(fn ->
      # Clean up after each test
      Checkend.reset()
    end)

    :ok
  end
end
```

### Using with ExUnit Case Templates

Create a reusable case template:

```elixir
defmodule MyApp.CheckendCase do
  use ExUnit.CaseTemplate

  setup do
    Checkend.Testing.setup()
    Checkend.configure(api_key: "test-key", enabled: true)

    on_exit(fn ->
      Checkend.reset()
    end)

    :ok
  end
end
```

Then use it in your tests:

```elixir
defmodule MyApp.OrdersTest do
  use MyApp.CheckendCase

  test "reports errors when order fails" do
    # Your test code
  end
end
```

## Asserting on Captured Errors

### Check if Errors Were Reported

```elixir
test "reports error when processing fails" do
  try do
    raise "Processing failed"
  rescue
    e -> Checkend.notify(e, __STACKTRACE__)
  end

  # Assert an error was captured
  assert Checkend.Testing.has_notices?()
  assert Checkend.Testing.notice_count() == 1
end
```

### Inspect Captured Errors

```elixir
test "captures error details correctly" do
  try do
    raise ArgumentError, message: "invalid input"
  rescue
    e ->
      Checkend.notify(e, __STACKTRACE__,
        context: %{input: "bad-data"},
        tags: ["validation"]
      )
  end

  # Get the captured notice
  notice = Checkend.Testing.last_notice()

  # Assert on error details
  assert notice.error_class == "ArgumentError"
  assert notice.message == "invalid input"
  assert notice.context["input"] == "bad-data"
  assert "validation" in notice.tags
end
```

### Multiple Errors

```elixir
test "captures multiple errors" do
  for i <- 1..3 do
    try do
      raise "Error #{i}"
    rescue
      e -> Checkend.notify(e, __STACKTRACE__)
    end
  end

  assert Checkend.Testing.notice_count() == 3

  # Get all notices
  notices = Checkend.Testing.notices()
  assert length(notices) == 3

  # Check first and last
  first = Checkend.Testing.first_notice()
  assert first.message == "Error 1"

  last = Checkend.Testing.last_notice()
  assert last.message == "Error 3"
end
```

### Clear Between Assertions

```elixir
test "can clear notices between operations" do
  try do
    raise "First error"
  rescue
    e -> Checkend.notify(e, __STACKTRACE__)
  end

  assert Checkend.Testing.notice_count() == 1

  # Clear captured notices
  Checkend.Testing.clear_notices()

  assert Checkend.Testing.notice_count() == 0
  refute Checkend.Testing.has_notices?()
end
```

## Testing Context and User Data

### Verify Context is Captured

```elixir
test "captures context data" do
  Checkend.set_context(%{
    order_id: 12345,
    feature: "checkout"
  })

  try do
    raise "Checkout failed"
  rescue
    e -> Checkend.notify(e, __STACKTRACE__)
  end

  notice = Checkend.Testing.last_notice()
  assert notice.context["order_id"] == 12345
  assert notice.context["feature"] == "checkout"
end
```

### Verify User Data is Captured

```elixir
test "captures user information" do
  Checkend.set_user(%{
    id: "user-123",
    email: "test@example.com"
  })

  try do
    raise "User action failed"
  rescue
    e -> Checkend.notify(e, __STACKTRACE__)
  end

  notice = Checkend.Testing.last_notice()
  assert notice.user["id"] == "user-123"
  assert notice.user["email"] == "test@example.com"
end
```

## Testing Ignored Exceptions

```elixir
test "ignores configured exceptions" do
  Checkend.configure(
    api_key: "test-key",
    enabled: true,
    ignored_exceptions: [ArgumentError]
  )

  try do
    raise ArgumentError, "should be ignored"
  rescue
    e -> Checkend.notify(e, __STACKTRACE__)
  end

  # No notice should be captured
  refute Checkend.Testing.has_notices?()
end
```

## Testing Before Notify Callbacks

```elixir
test "before_notify can modify notices" do
  Checkend.configure(
    api_key: "test-key",
    enabled: true,
    before_notify: [
      fn notice ->
        %{notice | context: Map.put(notice.context, "added_by_callback", true)}
      end
    ]
  )

  try do
    raise "Test"
  rescue
    e -> Checkend.notify(e, __STACKTRACE__)
  end

  notice = Checkend.Testing.last_notice()
  assert notice.context["added_by_callback"] == true
end

test "before_notify can skip notices" do
  Checkend.configure(
    api_key: "test-key",
    enabled: true,
    before_notify: [
      fn notice ->
        if String.contains?(notice.message, "skip-me"), do: false, else: true
      end
    ]
  )

  try do
    raise "Please skip-me"
  rescue
    e -> Checkend.notify(e, __STACKTRACE__)
  end

  refute Checkend.Testing.has_notices?()
end
```

## Testing Plug Integration

```elixir
defmodule MyAppWeb.ErrorHandlerTest do
  use ExUnit.Case
  use Plug.Test

  setup do
    Checkend.Testing.setup()
    Checkend.configure(api_key: "test-key", enabled: true)

    on_exit(fn -> Checkend.reset() end)
    :ok
  end

  test "captures request context" do
    conn =
      conn(:get, "/api/users?page=1")
      |> put_req_header("user-agent", "TestClient/1.0")

    # Simulate the error handler
    Checkend.Plugs.ErrorHandler.call(conn, [])

    try do
      raise "API error"
    rescue
      e -> Checkend.notify(e, __STACKTRACE__)
    end

    notice = Checkend.Testing.last_notice()
    assert notice.request["method"] == "GET"
    assert notice.request["url"] =~ "/api/users"
  end
end
```

## API Reference

| Function | Description |
|----------|-------------|
| `Checkend.Testing.setup/0` | Enable testing mode |
| `Checkend.Testing.teardown/0` | Disable testing mode |
| `Checkend.Testing.notices/0` | Get all captured notices |
| `Checkend.Testing.first_notice/0` | Get the first captured notice |
| `Checkend.Testing.last_notice/0` | Get the last captured notice |
| `Checkend.Testing.notice_count/0` | Get the count of captured notices |
| `Checkend.Testing.has_notices?/0` | Check if any notices were captured |
| `Checkend.Testing.clear_notices/0` | Clear all captured notices |

## Next Steps

- [Getting Started](getting-started.html) - Basic setup guide
- [Phoenix Integration](phoenix-integration.html) - Phoenix-specific setup
- [API Documentation](Checkend.Testing.html) - Full Testing module reference

---

*[Checkend](https://checkend.com) - Simple, powerful error monitoring. Project sponsored by [Furvur](https://furvur.com).*
