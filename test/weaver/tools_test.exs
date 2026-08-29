defmodule Weaver.ToolsInitTest do
  use ExUnit.Case, async: false

  alias Weaver.Tools

  describe "init/1" do
    test "initializes with config and returns ok tuple" do
      config = %Tools{
        base_dir: "/test/base/dir",
        tool_definitions: nil,
        tool_modules: %{}
      }

      # Note: Phoenix.PubSub.subscribe is internal state management, not an external action.
      # It will execute normally, subscribing the test process to the "messages" topic.
      result = Tools.init(config)

      assert result == {:ok, config}
    end

    test "preserves config state including tool_modules" do
      initial_modules = %{"mock-tool" => MockModule}
      config = %Tools{
        base_dir: "/test/dir",
        tool_definitions: [],
        tool_modules: initial_modules
      }

      {:ok, returned_config} = Tools.init(config)

      assert returned_config.base_dir == "/test/dir"
      assert returned_config.tool_modules == initial_modules
    end
  end
end
