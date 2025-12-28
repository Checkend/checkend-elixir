defmodule Checkend.Filters.IgnoreFilterTest do
  use ExUnit.Case

  alias Checkend.Filters.IgnoreFilter

  defmodule CustomError do
    defexception message: "custom error"
  end

  defmodule AnotherError do
    defexception message: "another error"
  end

  describe "should_ignore?/2" do
    test "ignores by module" do
      exception = %RuntimeError{message: "test"}
      assert IgnoreFilter.should_ignore?(exception, [RuntimeError])
      refute IgnoreFilter.should_ignore?(exception, [ArgumentError])
    end

    test "ignores by string name" do
      exception = %RuntimeError{message: "test"}
      assert IgnoreFilter.should_ignore?(exception, ["RuntimeError"])
      refute IgnoreFilter.should_ignore?(exception, ["ArgumentError"])
    end

    test "ignores custom exception by module" do
      exception = %CustomError{}
      assert IgnoreFilter.should_ignore?(exception, [CustomError])
      refute IgnoreFilter.should_ignore?(exception, [AnotherError])
    end

    test "ignores by regex" do
      exception = %RuntimeError{message: "test"}
      assert IgnoreFilter.should_ignore?(exception, [~r/.*Error/])
      refute IgnoreFilter.should_ignore?(exception, [~r/Custom.*/])
    end

    test "ignores with multiple patterns" do
      assert IgnoreFilter.should_ignore?(%RuntimeError{}, [RuntimeError, ArgumentError])
      assert IgnoreFilter.should_ignore?(%ArgumentError{}, [RuntimeError, ArgumentError])
      refute IgnoreFilter.should_ignore?(%KeyError{}, [RuntimeError, ArgumentError])
    end

    test "empty ignore list ignores nothing" do
      refute IgnoreFilter.should_ignore?(%RuntimeError{}, [])
      refute IgnoreFilter.should_ignore?(%CustomError{}, [])
    end
  end
end
