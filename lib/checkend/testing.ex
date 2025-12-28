defmodule Checkend.Testing do
  @moduledoc """
  Testing utilities for Checkend SDK.

  ## Usage

      # In your test setup
      Checkend.Testing.setup()
      Checkend.configure(api_key: "test-key", enabled: true)

      # In your tests
      try do
        raise "Test error"
      rescue
        e -> Checkend.notify(e, __STACKTRACE__)
      end

      assert Checkend.Testing.has_notices?()
      assert Checkend.Testing.notice_count() == 1

      # In your test teardown
      Checkend.reset()

  """

  alias Checkend.Notice

  @doc """
  Enable testing mode.
  """
  @spec setup() :: :ok
  def setup do
    :ets.new(:checkend_testing, [:named_table, :public, :set])
    :ets.insert(:checkend_testing, {:enabled, true})
    :ets.insert(:checkend_testing, {:notices, []})
    :ok
  rescue
    ArgumentError ->
      # Table already exists
      :ets.insert(:checkend_testing, {:enabled, true})
      :ets.insert(:checkend_testing, {:notices, []})
      :ok
  end

  @doc """
  Disable testing mode and clear notices.
  """
  @spec teardown() :: :ok
  def teardown do
    try do
      :ets.delete(:checkend_testing)
    rescue
      ArgumentError -> :ok
    end

    :ok
  end

  @doc """
  Check if testing mode is enabled.
  """
  @spec enabled?() :: boolean()
  def enabled? do
    try do
      case :ets.lookup(:checkend_testing, :enabled) do
        [{:enabled, true}] -> true
        _ -> false
      end
    rescue
      ArgumentError -> false
    end
  end

  @doc """
  Get all captured notices.
  """
  @spec notices() :: [Notice.t()]
  def notices do
    try do
      case :ets.lookup(:checkend_testing, :notices) do
        [{:notices, notices}] -> notices
        _ -> []
      end
    rescue
      ArgumentError -> []
    end
  end

  @doc """
  Get the last captured notice.
  """
  @spec last_notice() :: Notice.t() | nil
  def last_notice do
    case notices() do
      [] -> nil
      list -> List.last(list)
    end
  end

  @doc """
  Get the first captured notice.
  """
  @spec first_notice() :: Notice.t() | nil
  def first_notice do
    case notices() do
      [] -> nil
      [first | _] -> first
    end
  end

  @doc """
  Get the number of captured notices.
  """
  @spec notice_count() :: non_neg_integer()
  def notice_count do
    length(notices())
  end

  @doc """
  Check if any notices have been captured.
  """
  @spec has_notices?() :: boolean()
  def has_notices? do
    notice_count() > 0
  end

  @doc """
  Clear all captured notices.
  """
  @spec clear_notices() :: :ok
  def clear_notices do
    try do
      :ets.insert(:checkend_testing, {:notices, []})
    rescue
      ArgumentError -> :ok
    end

    :ok
  end

  @doc false
  @spec add_notice(Notice.t()) :: :ok
  def add_notice(notice) do
    try do
      current = notices()
      :ets.insert(:checkend_testing, {:notices, current ++ [notice]})
    rescue
      ArgumentError -> :ok
    end

    :ok
  end
end
