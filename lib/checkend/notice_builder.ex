defmodule Checkend.NoticeBuilder do
  @moduledoc """
  Builds Notice structs from exceptions.
  """

  alias Checkend.Notice
  alias Checkend.Filters.SanitizeFilter

  @max_backtrace_lines 100
  @max_message_length 10_000

  @doc """
  Build a Notice from an exception.
  """
  @spec build(Exception.t(), list(), keyword()) :: Notice.t()
  def build(exception, stacktrace, opts \\ []) do
    config = opts[:config] || Checkend.get_configuration()

    error_class = extract_class_name(exception)
    message = extract_message(exception)
    backtrace = extract_backtrace(stacktrace, config)

    sanitize_filter = SanitizeFilter.new(config.filter_keys)

    # Apply data sending toggles
    request_data = build_request_data(opts[:request], sanitize_filter, config)
    user_data = build_user_data(opts[:user], sanitize_filter, config)
    context_data = build_context_data(opts[:context], sanitize_filter, config)

    %Notice{
      error_class: error_class,
      message: message,
      backtrace: backtrace,
      fingerprint: opts[:fingerprint],
      tags: opts[:tags] || [],
      context: context_data,
      request: request_data,
      user: user_data,
      environment: config.environment,
      occurred_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      notifier: build_notifier(config)
    }
  end

  defp build_request_data(_request, _filter, %{send_request_data: false}), do: %{}

  defp build_request_data(request, filter, %{
         send_request_data: true,
         send_session_data: send_session
       }) do
    data = SanitizeFilter.filter(filter, request || %{})

    if send_session do
      data
    else
      Map.delete(data, "session") |> Map.delete(:session)
    end
  end

  defp build_request_data(request, filter, _config) do
    SanitizeFilter.filter(filter, request || %{})
  end

  defp build_user_data(_user, _filter, %{send_user_data: false}), do: %{}

  defp build_user_data(user, filter, _config) do
    SanitizeFilter.filter(filter, user || %{})
  end

  defp build_context_data(context, filter, %{send_environment: true}) do
    env_vars =
      System.get_env()
      |> Enum.into(%{})
      |> SanitizeFilter.filter(filter)

    context
    |> Kernel.||(%{})
    |> SanitizeFilter.filter(filter)
    |> Map.put("system_env", env_vars)
  end

  defp build_context_data(context, filter, _config) do
    SanitizeFilter.filter(filter, context || %{})
  end

  defp extract_class_name(exception) do
    exception.__struct__ |> to_string() |> String.replace("Elixir.", "")
  end

  defp extract_message(exception) do
    message = Exception.message(exception)

    if String.length(message) > @max_message_length do
      String.slice(message, 0, @max_message_length) <> "..."
    else
      message
    end
  end

  defp extract_backtrace(stacktrace, config) do
    root_path = config.root_path

    stacktrace
    |> Enum.take(@max_backtrace_lines)
    |> Enum.map(&format_stacktrace_entry(&1, root_path))
  end

  defp format_stacktrace_entry({module, function, arity, location}, root_path) do
    file = Keyword.get(location, :file, "nofile") |> to_string()
    file = clean_file_path(file, root_path)
    line = Keyword.get(location, :line, 0)
    arity_str = if is_list(arity), do: length(arity), else: arity
    "#{file}:#{line} in #{module}.#{function}/#{arity_str}"
  end

  defp format_stacktrace_entry(entry, _root_path) do
    inspect(entry)
  end

  defp clean_file_path(file, nil), do: file

  defp clean_file_path(file, root_path) when is_binary(root_path) do
    String.replace(file, root_path, "[PROJECT_ROOT]")
  end

  defp build_notifier(config) do
    notifier = %{
      "name" => "checkend-elixir",
      "version" => Checkend.version(),
      "language" => "elixir",
      "language_version" => System.version()
    }

    # Add app metadata if configured
    notifier
    |> maybe_add_app_name(config)
    |> maybe_add_revision(config)
  end

  defp maybe_add_app_name(notifier, %{app_name: nil}), do: notifier

  defp maybe_add_app_name(notifier, %{app_name: app_name}) when is_binary(app_name) do
    Map.put(notifier, "app_name", app_name)
  end

  defp maybe_add_app_name(notifier, _), do: notifier

  defp maybe_add_revision(notifier, %{revision: nil}), do: notifier

  defp maybe_add_revision(notifier, %{revision: revision}) when is_binary(revision) do
    Map.put(notifier, "revision", revision)
  end

  defp maybe_add_revision(notifier, _), do: notifier
end
