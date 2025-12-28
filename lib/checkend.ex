defmodule Checkend do
  @moduledoc """
  Elixir SDK for [Checkend](https://checkend.com) error monitoring and exception tracking.

  Checkend provides simple, powerful error monitoring for Elixir and Phoenix applications.
  This SDK enables automatic exception capture, error tracking, and real-time alerting
  for production applications.

  ## Features

    * **Async by default** - Non-blocking error reporting via GenServer
    * **Phoenix & Plug integration** - Automatic request context capture
    * **User tracking** - Associate errors with specific users
    * **Sensitive data filtering** - Automatic scrubbing of passwords, tokens, etc.
    * **Testing utilities** - Capture errors in tests without HTTP calls

  ## Quick Start

      # Configure the SDK
      Checkend.configure(api_key: "your-api-key")

      # Report an error
      try do
        do_something()
      rescue
        e -> Checkend.notify(e, __STACKTRACE__)
      end

  ## Configuration

      Checkend.configure(
        api_key: "your-api-key",
        endpoint: "https://app.checkend.com",
        environment: "production",
        enabled: true
      )

  See `configure/1` for all available options.

  ## Guides

    * [Getting Started](getting-started.html) - Installation and basic setup
    * [Phoenix Integration](phoenix-integration.html) - Phoenix and LiveView setup
    * [Testing Guide](testing.html) - Testing error reporting

  ## Links

    * [Checkend](https://checkend.com) - Error monitoring service
    * [GitHub](https://github.com/Checkend/checkend-elixir) - Source code
    * Project sponsored by [Furvur](https://furvur.com)

  """

  @version "1.0.0"

  alias Checkend.{Configuration, Notice, NoticeBuilder, Client, Worker, Testing}
  alias Checkend.Filters.IgnoreFilter

  @doc """
  Returns the SDK version.
  """
  def version, do: @version

  @doc """
  Configure the Checkend SDK.

  ## Options

    * `:api_key` - Your Checkend ingestion API key (required)
    * `:endpoint` - API endpoint URL (default: "https://app.checkend.com")
    * `:environment` - Environment name (auto-detected if not provided)
    * `:enabled` - Whether error reporting is enabled (default: true in production)
    * `:async_send` - Whether to send errors asynchronously (default: true)
    * `:max_queue_size` - Maximum queue size for async sending (default: 1000)
    * `:timeout` - HTTP request timeout in milliseconds (default: 15000)
    * `:filter_keys` - List of keys to filter from payloads
    * `:ignored_exceptions` - List of exception modules to ignore
    * `:before_notify` - List of callback functions to run before sending
    * `:debug` - Enable debug logging (default: false)

  ## Examples

      Checkend.configure(api_key: "your-api-key")

      Checkend.configure(
        api_key: "your-api-key",
        environment: "staging",
        filter_keys: ["custom_secret"]
      )

  """
  @spec configure(keyword()) :: :ok
  def configure(opts \\ []) do
    config = Configuration.new(opts)
    Application.put_env(:checkend, :configuration, config)

    if config.async_send and config.enabled do
      Worker.start()
    end

    :ok
  end

  @doc """
  Get the current configuration.
  """
  @spec get_configuration() :: Configuration.t() | nil
  def get_configuration do
    Application.get_env(:checkend, :configuration)
  end

  @doc """
  Report an exception to Checkend asynchronously.

  ## Options

    * `:context` - Additional context data
    * `:user` - User information
    * `:request` - Request information
    * `:fingerprint` - Custom fingerprint for grouping
    * `:tags` - List of tags for the error

  ## Examples

      try do
        do_something()
      rescue
        e ->
          Checkend.notify(e, __STACKTRACE__)
      end

      Checkend.notify(error, stacktrace,
        context: %{order_id: 123},
        user: %{id: "user-1"},
        tags: ["critical"]
      )

  """
  @spec notify(Exception.t(), list(), keyword()) :: :ok | {:error, term()}
  def notify(exception, stacktrace, opts \\ []) do
    config = get_configuration()

    cond do
      is_nil(config) ->
        {:error, :not_configured}

      not config.enabled ->
        :ok

      should_ignore?(exception, config) ->
        :ok

      true ->
        notice = build_notice(exception, stacktrace, opts, config)

        case run_before_notify(notice, config) do
          {:ok, notice} ->
            if Testing.enabled?() do
              Testing.add_notice(notice)
              :ok
            else
              if config.async_send do
                Worker.push(notice)
              else
                Client.send(notice, config)
              end
            end

          :skip ->
            :ok
        end
    end
  end

  @doc """
  Report an exception to Checkend synchronously.

  Returns the API response or an error.
  """
  @spec notify_sync(Exception.t(), list(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def notify_sync(exception, stacktrace, opts \\ []) do
    config = get_configuration()

    cond do
      is_nil(config) ->
        {:error, :not_configured}

      not config.enabled ->
        {:ok, %{}}

      should_ignore?(exception, config) ->
        {:ok, %{}}

      true ->
        notice = build_notice(exception, stacktrace, opts, config)

        case run_before_notify(notice, config) do
          {:ok, notice} ->
            if Testing.enabled?() do
              Testing.add_notice(notice)
              {:ok, %{id: 0, problem_id: 0}}
            else
              Client.send(notice, config)
            end

          :skip ->
            {:ok, %{}}
        end
    end
  end

  @doc """
  Set context data for the current process.
  """
  @spec set_context(map()) :: :ok
  def set_context(context) when is_map(context) do
    current = Process.get(:checkend_context, %{})
    Process.put(:checkend_context, Map.merge(current, context))
    :ok
  end

  @doc """
  Get the current context data.
  """
  @spec get_context() :: map()
  def get_context do
    Process.get(:checkend_context, %{})
  end

  @doc """
  Set user information for the current process.
  """
  @spec set_user(map()) :: :ok
  def set_user(user) when is_map(user) do
    Process.put(:checkend_user, user)
    :ok
  end

  @doc """
  Get the current user information.
  """
  @spec get_user() :: map()
  def get_user do
    Process.get(:checkend_user, %{})
  end

  @doc """
  Set request information for the current process.
  """
  @spec set_request(map()) :: :ok
  def set_request(request) when is_map(request) do
    Process.put(:checkend_request, request)
    :ok
  end

  @doc """
  Get the current request information.
  """
  @spec get_request() :: map()
  def get_request do
    Process.get(:checkend_request, %{})
  end

  @doc """
  Clear all context, user, and request data.
  """
  @spec clear() :: :ok
  def clear do
    Process.delete(:checkend_context)
    Process.delete(:checkend_user)
    Process.delete(:checkend_request)
    :ok
  end

  @doc """
  Wait for all queued notices to be sent.
  """
  @spec flush(timeout()) :: :ok
  def flush(timeout \\ 5000) do
    Worker.flush(timeout)
  end

  @doc """
  Stop the worker.
  """
  @spec stop() :: :ok
  def stop do
    Worker.stop()
  end

  @doc """
  Reset all state (useful for testing).
  """
  @spec reset() :: :ok
  def reset do
    stop()
    Application.delete_env(:checkend, :configuration)
    clear()
    Testing.teardown()
    :ok
  end

  # Private functions

  defp should_ignore?(exception, config) do
    IgnoreFilter.should_ignore?(exception, config.ignored_exceptions)
  end

  defp build_notice(exception, stacktrace, opts, config) do
    context = Map.merge(get_context(), opts[:context] || %{})
    user = opts[:user] || get_user()
    request = Map.merge(get_request(), opts[:request] || %{})

    NoticeBuilder.build(
      exception,
      stacktrace,
      context: context,
      user: user,
      request: request,
      fingerprint: opts[:fingerprint],
      tags: opts[:tags] || [],
      config: config
    )
  end

  defp run_before_notify(notice, config) do
    Enum.reduce_while(config.before_notify, {:ok, notice}, fn callback, {:ok, n} ->
      case callback.(n) do
        false -> {:halt, :skip}
        true -> {:cont, {:ok, n}}
        %Notice{} = updated -> {:cont, {:ok, updated}}
        _ -> {:cont, {:ok, n}}
      end
    end)
  end
end
