defmodule Checkend.ConfigurationTest do
  use ExUnit.Case

  alias Checkend.Configuration

  describe "new/1" do
    test "uses provided api_key" do
      config = Configuration.new(api_key: "test-key")
      assert config.api_key == "test-key"
    end

    test "uses default endpoint" do
      config = Configuration.new(api_key: "test-key")
      assert config.endpoint == "https://app.checkend.com"
    end

    test "uses custom endpoint" do
      config = Configuration.new(api_key: "test-key", endpoint: "https://custom.example.com")
      assert config.endpoint == "https://custom.example.com"
    end

    test "defaults environment to development" do
      config = Configuration.new(api_key: "test-key")
      assert config.environment == "development"
    end

    test "uses provided environment" do
      config = Configuration.new(api_key: "test-key", environment: "staging")
      assert config.environment == "staging"
    end

    test "enabled is false in development by default" do
      config = Configuration.new(api_key: "test-key", environment: "development")
      assert config.enabled == false
    end

    test "enabled is true in production by default" do
      config = Configuration.new(api_key: "test-key", environment: "production")
      assert config.enabled == true
    end

    test "explicit enabled overrides default" do
      config = Configuration.new(api_key: "test-key", enabled: true)
      assert config.enabled == true
    end

    test "includes default filter keys" do
      config = Configuration.new(api_key: "test-key")
      assert "password" in config.filter_keys
      assert "secret" in config.filter_keys
      assert "api_key" in config.filter_keys
    end

    test "custom filter keys extend defaults" do
      config = Configuration.new(api_key: "test-key", filter_keys: ["custom_key"])
      assert "password" in config.filter_keys
      assert "custom_key" in config.filter_keys
    end

    test "defaults async_send to true" do
      config = Configuration.new(api_key: "test-key")
      assert config.async_send == true
    end

    test "async_send can be disabled" do
      config = Configuration.new(api_key: "test-key", async_send: false)
      assert config.async_send == false
    end

    test "default timeout is 15000ms" do
      config = Configuration.new(api_key: "test-key")
      assert config.timeout == 15_000
    end

    test "custom timeout" do
      config = Configuration.new(api_key: "test-key", timeout: 30_000)
      assert config.timeout == 30_000
    end

    test "default max_queue_size is 1000" do
      config = Configuration.new(api_key: "test-key")
      assert config.max_queue_size == 1000
    end
  end

  describe "validate/1" do
    test "returns error when api_key is missing" do
      config = Configuration.new([])
      assert {:error, ["api_key is required"]} = Configuration.validate(config)
    end

    test "returns ok when api_key is present" do
      config = Configuration.new(api_key: "test-key")
      assert {:ok, ^config} = Configuration.validate(config)
    end
  end

  describe "valid?/1" do
    test "returns false when api_key is missing" do
      config = Configuration.new([])
      refute Configuration.valid?(config)
    end

    test "returns true when api_key is present" do
      config = Configuration.new(api_key: "test-key")
      assert Configuration.valid?(config)
    end
  end
end
