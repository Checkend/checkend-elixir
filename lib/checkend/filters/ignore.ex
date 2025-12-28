defmodule Checkend.Filters.IgnoreFilter do
  @moduledoc """
  Filter for ignoring certain exceptions.
  """

  @doc """
  Check if an exception should be ignored.
  """
  @spec should_ignore?(Exception.t(), [module() | String.t() | Regex.t()]) :: boolean()
  def should_ignore?(exception, patterns) do
    exception_module = exception.__struct__
    exception_name = exception_module |> to_string() |> String.replace("Elixir.", "")

    Enum.any?(patterns, fn pattern ->
      matches?(exception, exception_module, exception_name, pattern)
    end)
  end

  defp matches?(_exception, exception_module, _exception_name, pattern)
       when is_atom(pattern) do
    exception_module == pattern
  end

  defp matches?(_exception, _exception_module, exception_name, pattern)
       when is_binary(pattern) do
    exception_name == pattern or
      String.ends_with?(exception_name, "." <> pattern) or
      String.ends_with?(exception_name, pattern)
  end

  defp matches?(_exception, _exception_module, exception_name, %Regex{} = pattern) do
    Regex.match?(pattern, exception_name)
  end

  defp matches?(_, _, _, _), do: false
end
