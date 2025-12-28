defmodule CheckendTest do
  use ExUnit.Case

  alias Checkend.Testing

  setup do
    Checkend.reset()
    Testing.setup()
    :ok
  end

  describe "configure/1" do
    test "configures the SDK" do
      Checkend.configure(api_key: "test-key", enabled: true)
      config = Checkend.get_configuration()

      assert config.api_key == "test-key"
      assert config.enabled == true
    end

    test "uses default endpoint" do
      Checkend.configure(api_key: "test-key")
      config = Checkend.get_configuration()

      assert config.endpoint == "https://app.checkend.com"
    end
  end

  describe "notify/3" do
    test "captures exception" do
      Checkend.configure(api_key: "test-key", enabled: true, async_send: false)

      try do
        raise "Test error"
      rescue
        e -> Checkend.notify(e, __STACKTRACE__)
      end

      assert Testing.has_notices?()
      assert Testing.notice_count() == 1

      notice = Testing.last_notice()
      assert notice.error_class == "RuntimeError"
      assert notice.message == "Test error"
    end

    test "captures with context" do
      Checkend.configure(api_key: "test-key", enabled: true, async_send: false)

      try do
        raise "Test"
      rescue
        e -> Checkend.notify(e, __STACKTRACE__, context: %{order_id: 123})
      end

      notice = Testing.last_notice()
      assert notice.context["order_id"] == 123
    end

    test "captures with user" do
      Checkend.configure(api_key: "test-key", enabled: true, async_send: false)

      try do
        raise "Test"
      rescue
        e ->
          Checkend.notify(e, __STACKTRACE__, user: %{id: "user-1", email: "test@example.com"})
      end

      notice = Testing.last_notice()
      assert notice.user["id"] == "user-1"
      assert notice.user["email"] == "test@example.com"
    end

    test "captures with tags" do
      Checkend.configure(api_key: "test-key", enabled: true, async_send: false)

      try do
        raise "Test"
      rescue
        e -> Checkend.notify(e, __STACKTRACE__, tags: ["critical", "backend"])
      end

      notice = Testing.last_notice()
      assert notice.tags == ["critical", "backend"]
    end

    test "captures with fingerprint" do
      Checkend.configure(api_key: "test-key", enabled: true, async_send: false)

      try do
        raise "Test"
      rescue
        e -> Checkend.notify(e, __STACKTRACE__, fingerprint: "custom-fingerprint")
      end

      notice = Testing.last_notice()
      assert notice.fingerprint == "custom-fingerprint"
    end

    test "does not capture when disabled" do
      Checkend.configure(api_key: "test-key", enabled: false)

      try do
        raise "Test"
      rescue
        e -> Checkend.notify(e, __STACKTRACE__)
      end

      refute Testing.has_notices?()
    end

    test "ignores configured exceptions" do
      Checkend.configure(
        api_key: "test-key",
        enabled: true,
        async_send: false,
        ignored_exceptions: [RuntimeError]
      )

      try do
        raise "Test"
      rescue
        e -> Checkend.notify(e, __STACKTRACE__)
      end

      refute Testing.has_notices?()
    end
  end

  describe "context management" do
    test "set_context/1 and get_context/0" do
      Checkend.set_context(%{key1: "value1"})
      Checkend.set_context(%{key2: "value2"})

      context = Checkend.get_context()
      assert context[:key1] == "value1"
      assert context[:key2] == "value2"
    end

    test "set_user/1 and get_user/0" do
      Checkend.set_user(%{id: "user-1", email: "test@example.com"})

      user = Checkend.get_user()
      assert user[:id] == "user-1"
      assert user[:email] == "test@example.com"
    end

    test "set_request/1 and get_request/0" do
      Checkend.set_request(%{url: "https://example.com", method: "POST"})

      request = Checkend.get_request()
      assert request[:url] == "https://example.com"
      assert request[:method] == "POST"
    end

    test "clear/0 resets all context" do
      Checkend.set_context(%{key: "value"})
      Checkend.set_user(%{id: "user-1"})
      Checkend.set_request(%{url: "https://example.com"})

      Checkend.clear()

      assert Checkend.get_context() == %{}
      assert Checkend.get_user() == %{}
      assert Checkend.get_request() == %{}
    end
  end

  describe "before_notify callback" do
    test "callback is called" do
      test_pid = self()

      Checkend.configure(
        api_key: "test-key",
        enabled: true,
        async_send: false,
        before_notify: [
          fn notice ->
            send(test_pid, {:callback_called, notice})
            true
          end
        ]
      )

      try do
        raise "Test"
      rescue
        e -> Checkend.notify(e, __STACKTRACE__)
      end

      assert_receive {:callback_called, _notice}
      assert Testing.has_notices?()
    end

    test "callback can skip notice" do
      Checkend.configure(
        api_key: "test-key",
        enabled: true,
        async_send: false,
        before_notify: [fn _notice -> false end]
      )

      try do
        raise "Test"
      rescue
        e -> Checkend.notify(e, __STACKTRACE__)
      end

      refute Testing.has_notices?()
    end
  end

  describe "notify_sync/3" do
    test "returns response" do
      Checkend.configure(api_key: "test-key", enabled: true)

      result =
        try do
          raise "Test"
        rescue
          e -> Checkend.notify_sync(e, __STACKTRACE__)
        end

      assert {:ok, %{id: 0, problem_id: 0}} = result
      assert Testing.has_notices?()
    end
  end
end
