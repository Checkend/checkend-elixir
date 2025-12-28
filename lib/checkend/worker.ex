defmodule Checkend.Worker do
  @moduledoc """
  GenServer worker for async error sending.

  Implements exponential backoff throttling on errors:
  - On failure: throttle increases (delay = BASE_THROTTLE^throttle - 1)
  - On success: throttle decreases
  - Maximum throttle delay is capped at MAX_THROTTLE seconds
  """

  use GenServer

  alias Checkend.{Client, Configuration, Notice}

  # Exponential backoff base for throttling (same as Ruby SDK)
  @base_throttle 1.05
  @max_throttle 100
  @default_shutdown_timeout 5_000

  # Client API

  @doc """
  Start the worker.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start the worker if not already running.
  """
  def start do
    case Process.whereis(__MODULE__) do
      nil ->
        case start_link() do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          error -> error
        end

      _pid ->
        :ok
    end
  end

  @doc """
  Push a notice to the queue.
  """
  @spec push(Notice.t()) :: :ok | {:error, :queue_full}
  def push(notice) do
    case Process.whereis(__MODULE__) do
      nil -> {:error, :worker_not_running}
      _pid -> GenServer.call(__MODULE__, {:push, notice})
    end
  end

  @doc """
  Flush all pending notices.
  """
  @spec flush(timeout()) :: :ok
  def flush(timeout \\ nil) do
    timeout = timeout || get_shutdown_timeout()

    case Process.whereis(__MODULE__) do
      nil -> :ok
      _pid -> GenServer.call(__MODULE__, :flush, timeout)
    end
  end

  @doc """
  Stop the worker.
  """
  @spec stop() :: :ok
  def stop do
    timeout = get_shutdown_timeout()

    case Process.whereis(__MODULE__) do
      nil -> :ok
      _pid -> GenServer.stop(__MODULE__, :normal, timeout)
    end
  catch
    :exit, _ -> :ok
  end

  defp get_shutdown_timeout do
    case Checkend.get_configuration() do
      %Configuration{shutdown_timeout: timeout} when is_integer(timeout) -> timeout
      _ -> @default_shutdown_timeout
    end
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    {:ok, %{queue: :queue.new(), processing: false, throttle: 0}}
  end

  @impl true
  def handle_call({:push, notice}, _from, state) do
    config = Checkend.get_configuration()
    max_size = if config, do: config.max_queue_size, else: 1000

    if :queue.len(state.queue) >= max_size do
      {:reply, {:error, :queue_full}, state}
    else
      new_queue = :queue.in(notice, state.queue)
      new_state = %{state | queue: new_queue}

      if not state.processing do
        send(self(), :process_queue)
      end

      {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:flush, _from, state) do
    new_state = drain_queue(state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info(:process_queue, state) do
    new_state = process_next(state)
    {:noreply, new_state}
  end

  @impl true
  def terminate(_reason, state) do
    drain_queue(state)
    :ok
  end

  # Private functions

  defp process_next(%{queue: queue, throttle: throttle} = state) do
    case :queue.out(queue) do
      {{:value, notice}, new_queue} ->
        {result, new_throttle} = send_with_throttle(notice, throttle)
        send(self(), :process_queue)

        new_state = %{state | queue: new_queue, processing: true, throttle: new_throttle}

        case result do
          :ok -> new_state
          :error -> new_state
        end

      {:empty, _} ->
        %{state | processing: false}
    end
  end

  defp drain_queue(%{queue: queue, throttle: throttle} = state) do
    case :queue.out(queue) do
      {{:value, notice}, new_queue} ->
        {_result, new_throttle} = send_with_throttle(notice, throttle)
        drain_queue(%{state | queue: new_queue, throttle: new_throttle})

      {:empty, _} ->
        %{state | processing: false}
    end
  end

  defp send_with_throttle(notice, throttle) do
    # Apply throttle delay if needed
    if throttle > 0 do
      delay_ms = throttle_delay_ms(throttle)
      Process.sleep(delay_ms)
    end

    config = Checkend.get_configuration()

    if config do
      case Client.send(notice, config) do
        {:ok, _} ->
          # Success: decrease throttle
          {:ok, dec_throttle(throttle)}

        {:error, reason} ->
          Configuration.log(
            config,
            :error,
            "Failed to send notice: #{inspect(reason)}"
          )

          # Failure: increase throttle
          {:error, inc_throttle(throttle)}
      end
    else
      {:error, throttle}
    end
  end

  # Calculate throttle delay in milliseconds
  # Formula: (BASE_THROTTLE^throttle - 1) seconds, converted to ms
  defp throttle_delay_ms(throttle) do
    delay_seconds = :math.pow(@base_throttle, throttle) - 1
    # Cap at MAX_THROTTLE seconds
    capped_delay = min(delay_seconds, @max_throttle)
    round(capped_delay * 1000)
  end

  defp inc_throttle(throttle) do
    # Increase throttle, but cap at a level that would give MAX_THROTTLE delay
    # Since delay = BASE_THROTTLE^throttle - 1, we cap throttle to avoid excessive delays
    min(throttle + 1, 1000)
  end

  defp dec_throttle(throttle) do
    max(throttle - 1, 0)
  end
end
