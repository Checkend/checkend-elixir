defmodule Checkend.Filters.SanitizeFilterTest do
  use ExUnit.Case

  alias Checkend.Filters.SanitizeFilter

  setup do
    filter = SanitizeFilter.new(["password", "secret", "token"])
    {:ok, filter: filter}
  end

  describe "filter/2" do
    test "filters simple map", %{filter: filter} do
      data = %{"username" => "john", "password" => "secret123"}
      result = SanitizeFilter.filter(filter, data)

      assert result["username"] == "john"
      assert result["password"] == "[FILTERED]"
    end

    test "filters nested map", %{filter: filter} do
      data = %{
        "user" => %{
          "name" => "John",
          "credentials" => %{
            "password" => "secret123",
            "api_token" => "abc123"
          }
        }
      }

      result = SanitizeFilter.filter(filter, data)

      assert result["user"]["name"] == "John"
      assert result["user"]["credentials"]["password"] == "[FILTERED]"
      assert result["user"]["credentials"]["api_token"] == "[FILTERED]"
    end

    test "filters list of maps", %{filter: filter} do
      data = %{
        "users" => [
          %{"name" => "Alice", "password" => "pass1"},
          %{"name" => "Bob", "password" => "pass2"}
        ]
      }

      result = SanitizeFilter.filter(filter, data)

      assert Enum.at(result["users"], 0)["name"] == "Alice"
      assert Enum.at(result["users"], 0)["password"] == "[FILTERED]"
      assert Enum.at(result["users"], 1)["name"] == "Bob"
      assert Enum.at(result["users"], 1)["password"] == "[FILTERED]"
    end

    test "filters case insensitive", %{filter: filter} do
      data = %{
        "PASSWORD" => "value1",
        "Password" => "value2",
        "password" => "value3"
      }

      result = SanitizeFilter.filter(filter, data)

      assert result["PASSWORD"] == "[FILTERED]"
      assert result["Password"] == "[FILTERED]"
      assert result["password"] == "[FILTERED]"
    end

    test "filters partial match", %{filter: filter} do
      data = %{
        "user_password" => "secret",
        "password_hash" => "hash",
        "secret_key" => "key"
      }

      result = SanitizeFilter.filter(filter, data)

      assert result["user_password"] == "[FILTERED]"
      assert result["password_hash"] == "[FILTERED]"
      assert result["secret_key"] == "[FILTERED]"
    end

    test "preserves non-sensitive data", %{filter: filter} do
      data = %{
        "id" => 123,
        "name" => "Test",
        "active" => true,
        "value" => 3.14
      }

      result = SanitizeFilter.filter(filter, data)

      assert result["id"] == 123
      assert result["name"] == "Test"
      assert result["active"] == true
      assert result["value"] == 3.14
    end

    test "handles nil values", %{filter: filter} do
      data = %{"key" => nil, "password" => nil}
      result = SanitizeFilter.filter(filter, data)

      assert result["key"] == nil
      assert result["password"] == "[FILTERED]"
    end

    test "truncates long strings", %{filter: filter} do
      long_string = String.duplicate("x", 15_000)
      data = %{"message" => long_string}
      result = SanitizeFilter.filter(filter, data)

      assert String.length(result["message"]) == 10_003
      assert String.ends_with?(result["message"], "...")
    end

    test "handles deep nesting", %{filter: filter} do
      # Create deeply nested structure
      # Enum.reduce wraps from inside out, so final outermost level is 14
      data =
        Enum.reduce(0..14, %{"level" => 15}, fn i, acc ->
          %{"level" => i, "nested" => acc}
        end)

      # Should not raise, should handle max depth
      result = SanitizeFilter.filter(filter, data)
      assert result["level"] == 14
    end

    test "handles empty map", %{filter: filter} do
      result = SanitizeFilter.filter(filter, %{})
      assert result == %{}
    end

    test "handles atoms", %{filter: filter} do
      data = %{status: :active, password: :secret}
      result = SanitizeFilter.filter(filter, data)

      # Atom keys are converted to strings, atom values are converted to strings
      assert result["status"] == "active"
      assert result["password"] == "[FILTERED]"
    end
  end
end
