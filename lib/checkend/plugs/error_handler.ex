defmodule Checkend.Plugs.ErrorHandler do
  @moduledoc """
  Plug middleware for Checkend error reporting.

  ## Usage with Phoenix

      # In your endpoint.ex
      plug Checkend.Plugs.ErrorHandler

  ## Usage with Plug

      # In your router
      use Plug.ErrorHandler

      defp handle_errors(conn, %{kind: kind, reason: reason, stack: stack}) do
        Checkend.Plugs.ErrorHandler.handle_error(conn, kind, reason, stack)
      end

  """

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    # Clear context at the start of each request
    Checkend.clear()

    # Set request context
    set_request_context(conn)

    conn
  end

  @doc """
  Handle an error from Plug.ErrorHandler.
  """
  def handle_error(conn, _kind, reason, stack) do
    set_request_context(conn)
    Checkend.notify(wrap_reason(reason), stack)
  end

  @doc """
  Report an error with the current connection context.
  """
  def notify(conn, exception, stacktrace, opts \\ []) do
    set_request_context(conn)
    Checkend.notify(exception, stacktrace, opts)
  end

  defp set_request_context(conn) do
    request = %{
      "url" => request_url(conn),
      "method" => conn.method,
      "headers" => extract_headers(conn)
    }

    request =
      if map_size(conn.query_params) > 0 do
        Map.put(request, "params", conn.query_params)
      else
        request
      end

    Checkend.set_request(request)

    # Set request ID if available
    case get_request_id(conn) do
      nil -> :ok
      request_id -> Checkend.set_context(%{"request_id" => request_id})
    end
  end

  defp request_url(conn) do
    scheme = if conn.scheme == :https, do: "https", else: "http"
    port_str = port_string(conn.scheme, conn.port)
    "#{scheme}://#{conn.host}#{port_str}#{conn.request_path}"
  end

  defp port_string(:http, 80), do: ""
  defp port_string(:https, 443), do: ""
  defp port_string(_, port), do: ":#{port}"

  defp extract_headers(conn) do
    header_keys = [
      "user-agent",
      "accept",
      "accept-language",
      "referer",
      "content-type"
    ]

    conn.req_headers
    |> Enum.filter(fn {key, _} -> key in header_keys end)
    |> Enum.map(fn {key, value} -> {format_header_name(key), value} end)
    |> Enum.into(%{})
  end

  defp format_header_name(name) do
    name
    |> String.split("-")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join("-")
  end

  defp get_request_id(conn) do
    case Plug.Conn.get_resp_header(conn, "x-request-id") do
      [request_id | _] -> request_id
      _ -> nil
    end
  end

  defp wrap_reason(%{__exception__: true} = exception), do: exception

  defp wrap_reason(reason) do
    %RuntimeError{message: inspect(reason)}
  end
end
