defmodule Checkend.Configuration do
  @moduledoc """
  Configuration for the Checkend SDK.
  """

  @default_endpoint "https://app.checkend.com"
  @default_timeout 15_000
  @default_connect_timeout 5_000
  @default_max_queue_size 1000
  @default_shutdown_timeout 5_000

  @default_filter_keys [
    "password",
    "password_confirmation",
    "secret",
    "secret_key",
    "api_key",
    "apikey",
    "access_token",
    "auth_token",
    "authorization",
    "token",
    "credit_card",
    "card_number",
    "cvv",
    "cvc",
    "ssn",
    "social_security"
  ]

  defstruct [
    :api_key,
    :endpoint,
    :environment,
    :enabled,
    :async_send,
    :max_queue_size,
    :timeout,
    :connect_timeout,
    :shutdown_timeout,
    :filter_keys,
    :ignored_exceptions,
    :before_notify,
    :debug,
    # HTTP options
    :proxy,
    :ssl_verify,
    :ssl_ca_path,
    # App metadata
    :app_name,
    :revision,
    :root_path,
    # Data sending toggles
    :send_request_data,
    :send_session_data,
    :send_environment,
    :send_user_data,
    # Logger
    :logger
  ]

  @type t :: %__MODULE__{
          api_key: String.t() | nil,
          endpoint: String.t(),
          environment: String.t(),
          enabled: boolean(),
          async_send: boolean(),
          max_queue_size: pos_integer(),
          timeout: pos_integer(),
          connect_timeout: pos_integer(),
          shutdown_timeout: pos_integer(),
          filter_keys: [String.t()],
          ignored_exceptions: [module()],
          before_notify: [function()],
          debug: boolean(),
          proxy: String.t() | nil,
          ssl_verify: boolean(),
          ssl_ca_path: String.t() | nil,
          app_name: String.t() | nil,
          revision: String.t() | nil,
          root_path: String.t() | nil,
          send_request_data: boolean(),
          send_session_data: boolean(),
          send_environment: boolean(),
          send_user_data: boolean(),
          logger: module() | nil
        }

  @doc """
  Create a new configuration from options.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    api_key = opts[:api_key] || System.get_env("CHECKEND_API_KEY")

    endpoint =
      opts[:endpoint] ||
        System.get_env("CHECKEND_ENDPOINT") ||
        @default_endpoint

    environment =
      opts[:environment] ||
        System.get_env("CHECKEND_ENVIRONMENT") ||
        detect_environment()

    enabled =
      case opts[:enabled] do
        nil -> environment in ["production", "staging", "prod"]
        value -> value
      end

    debug =
      opts[:debug] ||
        System.get_env("CHECKEND_DEBUG") in ["true", "1", "yes"]

    ignored_exceptions = build_ignored_exceptions(opts[:ignored_exceptions] || [])

    %__MODULE__{
      api_key: api_key,
      endpoint: endpoint,
      environment: environment,
      enabled: enabled,
      async_send: Keyword.get(opts, :async_send, true),
      max_queue_size: opts[:max_queue_size] || @default_max_queue_size,
      timeout: opts[:timeout] || @default_timeout,
      connect_timeout: opts[:connect_timeout] || @default_connect_timeout,
      shutdown_timeout: opts[:shutdown_timeout] || @default_shutdown_timeout,
      filter_keys: @default_filter_keys ++ (opts[:filter_keys] || []),
      ignored_exceptions: ignored_exceptions,
      before_notify: opts[:before_notify] || [],
      debug: debug,
      # HTTP options
      proxy: opts[:proxy] || System.get_env("CHECKEND_PROXY"),
      ssl_verify: Keyword.get(opts, :ssl_verify, true),
      ssl_ca_path: opts[:ssl_ca_path],
      # App metadata
      app_name: opts[:app_name] || System.get_env("CHECKEND_APP_NAME"),
      revision: opts[:revision] || System.get_env("CHECKEND_REVISION"),
      root_path: opts[:root_path],
      # Data sending toggles
      send_request_data: Keyword.get(opts, :send_request_data, true),
      send_session_data: Keyword.get(opts, :send_session_data, true),
      send_environment: Keyword.get(opts, :send_environment, false),
      send_user_data: Keyword.get(opts, :send_user_data, true),
      # Logger
      logger: opts[:logger]
    }
  end

  defp build_ignored_exceptions(user_exceptions) do
    default_exceptions = default_ignored_exceptions()
    default_exceptions ++ user_exceptions
  end

  defp default_ignored_exceptions do
    exceptions = []

    # Phoenix exceptions (if available)
    exceptions =
      if Code.ensure_loaded?(Phoenix.Router.NoRouteError) do
        [Phoenix.Router.NoRouteError | exceptions]
      else
        exceptions
      end

    exceptions =
      if Code.ensure_loaded?(Phoenix.NotAcceptableError) do
        [Phoenix.NotAcceptableError | exceptions]
      else
        exceptions
      end

    # Ecto exceptions (if available)
    exceptions =
      if Code.ensure_loaded?(Ecto.NoResultsError) do
        [Ecto.NoResultsError | exceptions]
      else
        exceptions
      end

    exceptions =
      if Code.ensure_loaded?(Ecto.StaleEntryError) do
        [Ecto.StaleEntryError | exceptions]
      else
        exceptions
      end

    # Plug exceptions (if available)
    exceptions =
      if Code.ensure_loaded?(Plug.Conn.InvalidQueryError) do
        [Plug.Conn.InvalidQueryError | exceptions]
      else
        exceptions
      end

    exceptions
  end

  @doc """
  Validate the configuration.
  """
  @spec validate(t()) :: {:ok, t()} | {:error, [String.t()]}
  def validate(%__MODULE__{} = config) do
    errors = []

    errors =
      if is_nil(config.api_key) or config.api_key == "" do
        ["api_key is required" | errors]
      else
        errors
      end

    case errors do
      [] -> {:ok, config}
      _ -> {:error, errors}
    end
  end

  @doc """
  Check if the configuration is valid.
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = config) do
    case validate(config) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Log a message if debug is enabled.
  """
  @spec log(t(), atom(), String.t()) :: :ok
  def log(%__MODULE__{debug: true, logger: nil}, level, message) do
    require Logger
    apply(Logger, level, ["[Checkend] #{message}"])
    :ok
  end

  def log(%__MODULE__{debug: true, logger: logger}, level, message) when is_atom(logger) do
    apply(logger, level, ["[Checkend] #{message}"])
    :ok
  end

  def log(_, _, _), do: :ok

  defp detect_environment do
    cond do
      env = System.get_env("MIX_ENV") -> env
      env = System.get_env("ELIXIR_ENV") -> env
      env = System.get_env("ENVIRONMENT") -> env
      env = System.get_env("ENV") -> env
      true -> "development"
    end
  end
end
