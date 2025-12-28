# Phoenix Integration

This guide covers integrating [Checkend](https://checkend.com) error monitoring with Phoenix applications. The Checkend Elixir SDK provides seamless Plug integration for automatic error capture.

## Quick Setup

### 1. Add to Your Endpoint

Add the error handler plug to your Phoenix endpoint:

```elixir
# lib/my_app_web/endpoint.ex
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app

  # Add Checkend error handler early in the pipeline
  plug Checkend.Plugs.ErrorHandler

  # ... rest of your plugs
  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  # ...
end
```

### 2. Configure in Runtime

```elixir
# config/runtime.exs
if config_env() == :prod do
  config :checkend,
    api_key: System.fetch_env!("CHECKEND_API_KEY"),
    environment: "production"
end
```

## What Gets Captured Automatically

The `Checkend.Plugs.ErrorHandler` automatically captures:

- **Request URL** - Full URL of the failing request
- **HTTP Method** - GET, POST, PUT, etc.
- **Request Headers** - User-Agent, Accept, Content-Type, Referer
- **Query Parameters** - URL query string parameters
- **Request ID** - If using `Plug.RequestId`

## Adding User Context

Track which users experience errors by setting user context in your authentication plug:

```elixir
# lib/my_app_web/plugs/auth.ex
defmodule MyAppWeb.Plugs.Auth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_current_user(conn) do
      nil ->
        conn

      user ->
        # Set user context for Checkend
        Checkend.set_user(%{
          id: user.id,
          email: user.email,
          name: user.name
        })

        assign(conn, :current_user, user)
    end
  end
end
```

## Adding Custom Context

Add application-specific context to errors:

```elixir
# In a controller or plug
def call(conn, _opts) do
  Checkend.set_context(%{
    tenant_id: conn.assigns.tenant_id,
    feature_flags: get_feature_flags(conn)
  })

  conn
end
```

## Manual Error Reporting in Controllers

Report errors manually with full request context:

```elixir
defmodule MyAppWeb.OrderController do
  use MyAppWeb, :controller

  def create(conn, params) do
    case Orders.create(params) do
      {:ok, order} ->
        json(conn, order)

      {:error, reason} ->
        # Report the error with context
        Checkend.Plugs.ErrorHandler.notify(
          conn,
          %RuntimeError{message: "Order creation failed: #{inspect(reason)}"},
          [],
          context: %{params: params},
          tags: ["orders", "creation-failed"]
        )

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create order"})
    end
  end
end
```

## Using with Plug.ErrorHandler

If you're using `Plug.ErrorHandler` directly:

```elixir
defmodule MyAppWeb.Router do
  use Phoenix.Router
  use Plug.ErrorHandler

  # ... your routes ...

  @impl Plug.ErrorHandler
  defp handle_errors(conn, %{kind: kind, reason: reason, stack: stack}) do
    Checkend.Plugs.ErrorHandler.handle_error(conn, kind, reason, stack)

    conn
    |> put_status(:internal_server_error)
    |> put_view(MyAppWeb.ErrorView)
    |> render("500.html")
  end
end
```

## LiveView Integration

For Phoenix LiveView, handle errors in your socket:

```elixir
defmodule MyAppWeb.UserSocket do
  use Phoenix.Socket

  def connect(params, socket, _connect_info) do
    case authenticate(params) do
      {:ok, user} ->
        Checkend.set_user(%{id: user.id, email: user.email})
        {:ok, assign(socket, :user, user)}

      {:error, reason} ->
        :error
    end
  end
end
```

And in your LiveView modules:

```elixir
defmodule MyAppWeb.DashboardLive do
  use MyAppWeb, :live_view

  @impl true
  def handle_event("action", params, socket) do
    try do
      perform_action(params)
      {:noreply, socket}
    rescue
      e ->
        Checkend.notify(e, __STACKTRACE__,
          context: %{live_view: "DashboardLive", event: "action"},
          user: %{id: socket.assigns.user.id}
        )

        {:noreply, put_flash(socket, :error, "Something went wrong")}
    end
  end
end
```

## Filtering Sensitive Data

Configure sensitive data filtering:

```elixir
Checkend.configure(
  api_key: "your-api-key",
  filter_keys: [
    "password",
    "credit_card",
    "ssn",
    "api_secret"
  ]
)
```

By default, common sensitive keys are already filtered. See `Checkend.configure/1` for the full list.

## Next Steps

- [Testing Guide](testing.html) - Test error reporting
- [API Documentation](Checkend.html) - Full API reference
- [Getting Started](getting-started.html) - Basic setup guide

---

*[Checkend](https://checkend.com) - Simple, powerful error monitoring for Phoenix applications. Project sponsored by [Furvur](https://furvur.com).*
