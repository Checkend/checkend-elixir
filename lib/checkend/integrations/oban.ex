defmodule Checkend.Integrations.Oban do
  @moduledoc """
  Oban integration for capturing job errors.

  ## Installation

  Add to your application's start function or a supervisor:

      # In application.ex
      def start(_type, _args) do
        Checkend.Integrations.Oban.attach()

        children = [
          # ...
        ]

        Supervisor.start_link(children, strategy: :one_for_one)
      end

  Or manually attach in your config:

      # In config/runtime.exs
      if config_env() == :prod do
        Checkend.configure(api_key: System.get_env("CHECKEND_API_KEY"))
        Checkend.Integrations.Oban.attach()
      end

  ## Configuration

  The integration will automatically:
  - Capture job exceptions
  - Include job context (queue, worker, args, attempt)
  - Sanitize job arguments
  - Tag errors with "oban"
  """

  alias Checkend.Filters.SanitizeFilter

  @handler_id :checkend_oban_handler

  @doc """
  Attach the Oban telemetry handler.

  Returns `:ok` if successful, `{:error, reason}` if Oban is not available.
  """
  @spec attach() :: :ok | {:error, :oban_not_available}
  def attach do
    if oban_available?() do
      :telemetry.attach(
        @handler_id,
        [:oban, :job, :exception],
        &handle_exception/4,
        %{}
      )

      :ok
    else
      {:error, :oban_not_available}
    end
  end

  @doc """
  Detach the Oban telemetry handler.
  """
  @spec detach() :: :ok
  def detach do
    :telemetry.detach(@handler_id)
    :ok
  rescue
    _ -> :ok
  end

  @doc """
  Check if Oban is available.
  """
  @spec oban_available?() :: boolean()
  def oban_available? do
    Code.ensure_loaded?(Oban)
  end

  @doc false
  def handle_exception(
        [:oban, :job, :exception],
        _measurements,
        %{kind: kind, reason: reason, stacktrace: stacktrace} = metadata,
        _config
      ) do
    config = Checkend.get_configuration()

    if config && config.enabled do
      exception = normalize_exception(kind, reason)
      job_context = extract_job_context(metadata, config)

      Checkend.notify(
        exception,
        stacktrace,
        context: job_context,
        tags: ["oban"]
      )
    end
  rescue
    e ->
      if config = Checkend.get_configuration() do
        Checkend.Configuration.log(
          config,
          :error,
          "Failed to notify Oban error: #{inspect(e)}"
        )
      end
  end

  def handle_exception(_, _, _, _), do: :ok

  defp normalize_exception(:error, %{__exception__: true} = exception), do: exception
  defp normalize_exception(:error, reason), do: %RuntimeError{message: inspect(reason)}

  defp normalize_exception(:throw, reason),
    do: %RuntimeError{message: "throw: #{inspect(reason)}"}

  defp normalize_exception(:exit, reason), do: %RuntimeError{message: "exit: #{inspect(reason)}"}
  defp normalize_exception(_, reason), do: %RuntimeError{message: inspect(reason)}

  defp extract_job_context(metadata, config) do
    job = Map.get(metadata, :job, %{})

    %{
      oban: %{
        queue: get_job_field(job, :queue),
        worker: get_job_field(job, :worker),
        attempt: get_job_field(job, :attempt, 1),
        max_attempts: get_job_field(job, :max_attempts, 20),
        id: get_job_field(job, :id),
        args: sanitize_args(get_job_field(job, :args, %{}), config),
        state: get_job_field(job, :state),
        inserted_at: format_datetime(get_job_field(job, :inserted_at)),
        scheduled_at: format_datetime(get_job_field(job, :scheduled_at))
      }
    }
  end

  defp get_job_field(job, field, default \\ nil) do
    cond do
      is_map(job) && Map.has_key?(job, field) ->
        Map.get(job, field, default)

      is_struct(job) && Map.has_key?(job, field) ->
        Map.get(job, field, default)

      true ->
        default
    end
  end

  defp sanitize_args(args, config) when is_map(args) do
    filter = SanitizeFilter.new(config.filter_keys)
    SanitizeFilter.filter(filter, args)
  rescue
    _ -> %{"_hidden" => "[ARGS HIDDEN]"}
  end

  defp sanitize_args(args, _config), do: args

  defp format_datetime(nil), do: nil

  defp format_datetime(%DateTime{} = dt) do
    DateTime.to_iso8601(dt)
  end

  defp format_datetime(%NaiveDateTime{} = dt) do
    NaiveDateTime.to_iso8601(dt)
  end

  defp format_datetime(other), do: inspect(other)
end
