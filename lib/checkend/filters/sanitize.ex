defmodule Checkend.Filters.SanitizeFilter do
  @moduledoc """
  Filter for sanitizing sensitive data.
  """

  @filtered_value "[FILTERED]"
  @max_depth 10
  @max_string_length 10_000

  defstruct [:filter_keys]

  @type t :: %__MODULE__{
          filter_keys: [String.t()]
        }

  @doc """
  Create a new SanitizeFilter.
  """
  @spec new([String.t()]) :: t()
  def new(filter_keys) do
    %__MODULE__{
      filter_keys: Enum.map(filter_keys, &String.downcase/1)
    }
  end

  @doc """
  Recursively filter sensitive data from a map.
  """
  @spec filter(t(), map() | any()) :: map() | any()
  def filter(%__MODULE__{} = filter, data) when is_map(data) do
    filter_value(filter, data, 0, MapSet.new())
  end

  def filter(_, data), do: data

  defp filter_value(_filter, _data, depth, _seen) when depth > @max_depth do
    "[MAX DEPTH EXCEEDED]"
  end

  defp filter_value(filter, data, depth, seen) when is_map(data) do
    # Check for circular reference using map identity
    ref = :erlang.phash2(data)

    if MapSet.member?(seen, ref) do
      "[CIRCULAR]"
    else
      new_seen = MapSet.put(seen, ref)

      data
      |> Enum.map(fn {key, value} ->
        # Convert atom keys to strings for consistent JSON output
        key_str = to_string(key)

        if should_filter?(filter, key_str) do
          {key_str, @filtered_value}
        else
          {key_str, filter_value(filter, value, depth + 1, new_seen)}
        end
      end)
      |> Enum.into(%{})
    end
  end

  defp filter_value(filter, data, depth, seen) when is_list(data) do
    Enum.map(data, &filter_value(filter, &1, depth + 1, seen))
  end

  defp filter_value(_filter, data, _depth, _seen) when is_binary(data) do
    truncate_string(data)
  end

  defp filter_value(_filter, data, _depth, _seen)
       when is_number(data) or is_boolean(data) or is_nil(data) do
    data
  end

  defp filter_value(_filter, data, _depth, _seen) when is_atom(data) do
    to_string(data)
  end

  defp filter_value(_filter, data, _depth, _seen) do
    truncate_string(inspect(data))
  end

  defp should_filter?(%__MODULE__{filter_keys: keys}, key) do
    key_lower = String.downcase(key)

    Enum.any?(keys, fn filter_key ->
      String.contains?(key_lower, filter_key)
    end)
  end

  defp truncate_string(str) when byte_size(str) > @max_string_length do
    String.slice(str, 0, @max_string_length) <> "..."
  end

  defp truncate_string(str), do: str
end
