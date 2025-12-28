defmodule Checkend.Client do
  @moduledoc """
  HTTP client for sending notices to Checkend.
  """

  alias Checkend.{Configuration, Notice}

  @doc """
  Send a notice to Checkend.
  """
  @spec send(Notice.t(), Configuration.t()) :: {:ok, map()} | {:error, term()}
  def send(notice, config) do
    if is_nil(config.api_key) or config.api_key == "" do
      Configuration.log(config, :error, "Cannot send notice: api_key not configured")
      {:error, :no_api_key}
    else
      payload = Notice.to_payload(notice)
      do_send(payload, config)
    end
  end

  defp do_send(payload, config) do
    url = "#{config.endpoint}/ingest/v1/errors"
    body = encode_json(payload)

    headers = [
      {~c"content-type", ~c"application/json"},
      {~c"checkend-ingestion-key", String.to_charlist(config.api_key)},
      {~c"user-agent", String.to_charlist("checkend-elixir/#{Checkend.version()}")}
    ]

    request = {String.to_charlist(url), headers, ~c"application/json", body}

    http_options = build_http_options(config)

    case :httpc.request(:post, request, http_options, []) do
      {:ok, {{_, 201, _}, _, response_body}} ->
        Configuration.log(config, :debug, "Notice sent successfully")
        {:ok, decode_json(response_body)}

      {:ok, {{_, status_code, _}, _, response_body}} ->
        handle_http_error(status_code, response_body, config)

      {:error, reason} ->
        Configuration.log(config, :error, "Network error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_http_options(config) do
    options = [
      timeout: config.timeout,
      connect_timeout: config.connect_timeout || config.timeout
    ]

    # Add SSL options
    options = add_ssl_options(options, config)

    # Add proxy options
    add_proxy_options(options, config)
  end

  defp add_ssl_options(options, %{ssl_verify: false}) do
    ssl_opts = [verify: :verify_none]
    Keyword.put(options, :ssl, ssl_opts)
  end

  defp add_ssl_options(options, %{ssl_verify: true, ssl_ca_path: nil}) do
    # Use default SSL verification
    options
  end

  defp add_ssl_options(options, %{ssl_verify: true, ssl_ca_path: ca_path})
       when is_binary(ca_path) do
    ssl_opts = [
      verify: :verify_peer,
      cacertfile: String.to_charlist(ca_path)
    ]

    Keyword.put(options, :ssl, ssl_opts)
  end

  defp add_ssl_options(options, _config), do: options

  defp add_proxy_options(options, %{proxy: nil}), do: options

  defp add_proxy_options(options, %{proxy: proxy}) when is_binary(proxy) do
    case parse_proxy_url(proxy) do
      {:ok, proxy_opts} ->
        Keyword.put(options, :proxy, proxy_opts)

      :error ->
        options
    end
  end

  defp add_proxy_options(options, _config), do: options

  defp parse_proxy_url(proxy_url) do
    case URI.parse(proxy_url) do
      %URI{host: host, port: port} when is_binary(host) and is_integer(port) ->
        {:ok, {{String.to_charlist(host), port}, []}}

      %URI{host: host} when is_binary(host) ->
        # Default to port 8080 for proxy
        {:ok, {{String.to_charlist(host), 8080}, []}}

      _ ->
        :error
    end
  end

  defp handle_http_error(401, _body, config) do
    Configuration.log(config, :error, "Authentication failed: invalid API key")
    {:error, :unauthorized}
  end

  defp handle_http_error(422, body, config) do
    Configuration.log(config, :error, "Validation error: #{body}")
    {:error, :validation_error}
  end

  defp handle_http_error(429, _body, config) do
    Configuration.log(config, :warning, "Rate limited by Checkend API")
    {:error, :rate_limited}
  end

  defp handle_http_error(status_code, _body, config) when status_code >= 500 do
    Configuration.log(config, :error, "Server error: #{status_code}")
    {:error, :server_error}
  end

  defp handle_http_error(status_code, _body, config) do
    Configuration.log(config, :error, "HTTP error: #{status_code}")
    {:error, {:http_error, status_code}}
  end

  defp encode_json(data) do
    if Code.ensure_loaded?(Jason) do
      Jason.encode!(data)
    else
      # Fallback to simple JSON encoding
      simple_encode(data)
    end
  end

  defp decode_json(data) do
    data_string = to_string(data)

    if Code.ensure_loaded?(Jason) do
      case Jason.decode(data_string) do
        {:ok, decoded} -> decoded
        _ -> %{}
      end
    else
      %{}
    end
  end

  defp simple_encode(data) when is_map(data) do
    pairs =
      data
      |> Enum.map(fn {k, v} -> "#{simple_encode(to_string(k))}:#{simple_encode(v)}" end)
      |> Enum.join(",")

    "{#{pairs}}"
  end

  defp simple_encode(data) when is_list(data) do
    items = Enum.map(data, &simple_encode/1) |> Enum.join(",")
    "[#{items}]"
  end

  defp simple_encode(data) when is_binary(data) do
    escaped =
      data
      |> String.replace("\\", "\\\\")
      |> String.replace("\"", "\\\"")
      |> String.replace("\n", "\\n")
      |> String.replace("\r", "\\r")
      |> String.replace("\t", "\\t")

    "\"#{escaped}\""
  end

  defp simple_encode(data) when is_number(data), do: to_string(data)
  defp simple_encode(true), do: "true"
  defp simple_encode(false), do: "false"
  defp simple_encode(nil), do: "null"
  defp simple_encode(data) when is_atom(data), do: simple_encode(to_string(data))
  defp simple_encode(data), do: simple_encode(inspect(data))
end
