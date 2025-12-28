defmodule Checkend.Notice do
  @moduledoc """
  Represents an error notice to be sent to Checkend.
  """

  defstruct [
    :error_class,
    :message,
    :backtrace,
    :fingerprint,
    :tags,
    :context,
    :request,
    :user,
    :environment,
    :occurred_at,
    :notifier
  ]

  @type t :: %__MODULE__{
          error_class: String.t(),
          message: String.t(),
          backtrace: [String.t()],
          fingerprint: String.t() | nil,
          tags: [String.t()],
          context: map(),
          request: map(),
          user: map(),
          environment: String.t(),
          occurred_at: String.t(),
          notifier: map()
        }

  @doc """
  Convert the notice to an API payload.
  """
  @spec to_payload(t()) :: map()
  def to_payload(%__MODULE__{} = notice) do
    context =
      Map.merge(%{"environment" => notice.environment}, notice.context)

    payload = %{
      "error" => %{
        "class" => notice.error_class,
        "message" => notice.message,
        "backtrace" => notice.backtrace,
        "occurred_at" => notice.occurred_at
      },
      "context" => context,
      "notifier" => notice.notifier
    }

    payload =
      if notice.fingerprint do
        put_in(payload, ["error", "fingerprint"], notice.fingerprint)
      else
        payload
      end

    payload =
      if notice.tags != [] do
        put_in(payload, ["error", "tags"], notice.tags)
      else
        payload
      end

    payload =
      if map_size(notice.request) > 0 do
        Map.put(payload, "request", notice.request)
      else
        payload
      end

    if map_size(notice.user) > 0 do
      Map.put(payload, "user", notice.user)
    else
      payload
    end
  end
end
