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
        tool_definitions: nil,
        tool_modules: initial_modules
      }

      {:ok, returned_config} = Tools.init(config)

      assert returned_config.base_dir == "/test/dir"
      assert returned_config.tool_modules == initial_modules
    end
  end
end

defmodule Weaver.ToolsRetrievalTest do
  use ExUnit.Case, async: false

  alias Weaver.Tools

  describe "get_tool_definitions/1" do
    setup do
      # Create a temporary directory structure for STDIO tool testing
      tmp_dir = System.tmp_dir!()
      tool_dir = Path.join([tmp_dir, "test_tools_#{:erlang.unique_integer([:positive])}"])
      File.mkdir_p!(Path.join(tool_dir, "test-stdio-tool"))
      
      definition = %{
        type: "function",
        function: %{
          name: "test-stdio-tool",
          description: "A test STDIO tool",
          parameters: %{type: "object", properties: %{}}
        }
      }

      File.write!(Path.join(tool_dir, "test-stdio-tool/definition.json"), Jason.encode!(definition))

      on_exit(fn ->
        File.rm_rf!(tool_dir)
      end)

      %{tool_dir: tool_dir}
    end

    test "fetches STDIO tool definitions from filesystem", %{tool_dir: tool_dir} do
      config = %Tools{
        base_dir: tool_dir,
        tool_definitions: nil,
        tool_modules: %{}
      }

      {:ok, _pid} = Tools.start_link(config)

      definitions = Tools.get_tool_definitions(["test-stdio-tool"])

      assert length(definitions) == 1
      assert hd(definitions)[:type] == "function"
      assert hd(definitions)[:function][:name] == "test-stdio-tool"
      assert hd(definitions)[:function][:description] == "A test STDIO tool"
    end

    test "fetches module-based tool definitions from tool_modules" do
      defmodule MockToolModule do
        @behaviour Weaver.Tools.Tool

        @impl true
        def definition() do
          %{
            type: "function",
            function: %{
              name: "mock-module-tool",
              description: "A test module tool",
              parameters: %{type: "object", properties: %{}}
            }
          }
        end

        @impl true
        def run(_tool_call) do
          "mock response"
        end
      end

      config = %Tools{
        base_dir: "/tmp/unused",
        tool_definitions: nil,
        tool_modules: %{"mock-module-tool" => MockToolModule}
      }

      {:ok, _pid} = Tools.start_link(config)

      definitions = Tools.get_tool_definitions(["mock-module-tool"])

      assert length(definitions) == 1
      assert hd(definitions)[:type] == "function"
      assert hd(definitions)[:function][:name] == "mock-module-tool"
      assert hd(definitions)[:function][:description] == "A test module tool"
    end

    test "returns definitions for both STDIO and module-based tools", %{tool_dir: tool_dir} do
      defmodule MixedMockToolModule do
        @behaviour Weaver.Tools.Tool

        @impl true
        def definition() do
          %{
            type: "function",
            function: %{
              name: "mixed-mock-tool",
              description: "A mixed test tool",
              parameters: %{type: "object", properties: %{}}
            }
          }
        end

        @impl true
        def run(_tool_call) do
          "mixed mock response"
        end
      end

      config = %Tools{
        base_dir: tool_dir,
        tool_definitions: nil,
        tool_modules: %{"mixed-mock-tool" => MixedMockToolModule}
      }

      {:ok, _pid} = Tools.start_link(config)

      definitions = Tools.get_tool_definitions(["test-stdio-tool", "mixed-mock-tool"])

      assert length(definitions) == 2
      
      stdio_def = Enum.find(definitions, fn d -> d[:function][:name] == "test-stdio-tool" end)
      module_def = Enum.find(definitions, fn d -> d[:function][:name] == "mixed-mock-tool" end)

      assert stdio_def != nil
      assert module_def != nil
      assert stdio_def[:function][:description] == "A test STDIO tool"
      assert module_def[:function][:description] == "A mixed test tool"
    end
  end
end

defmodule Weaver.ToolsHandlingTest do
  use ExUnit.Case, async: false

  alias Weaver.Tools
  import Phoenix.PubSub, only: [subscribe: 2]

  # Helper to safely stop the GenServer
  defp stop_tools_server() do
    try do
      GenServer.stop(Weaver.Tools)
    catch
      :exit, _ -> :ok
    end
  end

  describe "handle_info - Module-based tool calls" do
    setup do
      defmodule HandlingTestMockModule do
        @behaviour Weaver.Tools.Tool

        @impl true
        def definition() do
          %{
            type: "function",
            function: %{
              name: "handling-mock-tool",
              description: "A handling test module tool",
              parameters: %{type: "object", properties: %{}}
            }
          }
        end

        @impl true
        def run(_tool_call) do
          "handling mock response"
        end
      end

      config = %Tools{
        base_dir: "/tmp/unused",
        tool_definitions: [
          %{
            type: "function",
            function: %{
              name: "handling-mock-tool",
              description: "A handling test module tool",
              parameters: %{type: "object", properties: %{}}
            }
          }
        ],
        tool_modules: %{"handling-mock-tool" => HandlingTestMockModule}
      }

      # Stop any existing server first
      stop_tools_server()
      Process.sleep(50)

      {:ok, pid} = Tools.start_link(config)

      on_exit(fn ->
        stop_tools_server()
      end)

      %{pid: pid}
    end

    test "formats response correctly for module-based tools and broadcasts to messages", %{pid: pid} do
      subscribe(Weaver.PubSub, "messages")

      tool_call = %{
        id: "call_123",
        type: "function",
        function: %{
          name: "handling-mock-tool",
          arguments: "{}"
        }
      }

      message = %{
        role: "assistant",
        tool_calls: [tool_call]
      }

      send(pid, message)

      # Wait a bit for the message to be broadcast
      Process.sleep(200)

      receive do
        [response] ->
          assert response[:id] == "call_123"
          assert response[:role] == "tool"
          assert response[:content] == "handling mock response"
      after
        2000 ->
          flunk("Timed out waiting for broadcast message")
      end
    end
  end

  describe "handle_info - STDIO tool calls" do
    setup do
      tmp_dir = System.tmp_dir!()
      tool_dir = Path.join([tmp_dir, "test_stdio_handling_#{:erlang.unique_integer([:positive])}"])
      stdio_tool_dir = Path.join(tool_dir, "test-stdio-handler")
      File.mkdir_p!(stdio_tool_dir)

      definition = %{
        type: "function",
        function: %{
          name: "test-stdio-handler",
          description: "A test STDIO tool for handling",
          parameters: %{type: "object", properties: %{}}
        }
      }

      File.write!(Path.join(stdio_tool_dir, "definition.json"), Jason.encode!(definition))

      # Create a simple script that echoes back
      script = """
      #!/bin/sh
      read -r input
      echo "{\"result\": \"stdio output\"}"
      """

      File.write!(Path.join(stdio_tool_dir, "run"), script)
      File.chmod!(Path.join(stdio_tool_dir, "run"), 0o755)

      config = %Tools{
        base_dir: tool_dir,
        tool_definitions: [definition],
        tool_modules: %{}
      }

      # Stop any existing server first
      stop_tools_server()
      Process.sleep(50)

      {:ok, pid} = Tools.start_link(config)

      on_exit(fn ->
        stop_tools_server()
        File.rm_rf!(tool_dir)
      end)

      %{pid: pid, tool_dir: tool_dir}
    end

    test "calls STDIO tool and broadcasts response to messages", %{pid: pid} do
      subscribe(Weaver.PubSub, "messages")

      tool_call = %{
        id: "call_stdio_1",
        type: "function",
        function: %{
          name: "test-stdio-handler",
          arguments: "{}"
        }
      }

      message = %{
        role: "assistant",
        tool_calls: [tool_call]
      }

      send(pid, message)

      Process.sleep(500)

      receive do
        [response] ->
          assert response[:id] == "call_stdio_1"
          assert response[:role] == "tool"
          assert response[:content] =~ "result"
      after
        2000 ->
          flunk("Timed out waiting for STDIO tool response")
      end
    end
  end

  describe "handle_info - Invalid tool calls" do
    setup do
      config = %Tools{
        base_dir: "/tmp/unused",
        tool_definitions: [
          %{
            type: "function",
            function: %{
              name: "existing-tool",
              description: "An existing tool",
              parameters: %{type: "object", properties: %{}}
            }
          }
        ],
        tool_modules: %{}
      }

      # Stop any existing server first
      stop_tools_server()
      Process.sleep(50)

      {:ok, pid} = Tools.start_link(config)

      on_exit(fn ->
        stop_tools_server()
      end)

      %{pid: pid}
    end

    test "returns error message for invalid tool names", %{pid: pid} do
      subscribe(Weaver.PubSub, "messages")

      tool_call = %{
        id: "call_invalid",
        type: "function",
        function: %{
          name: "nonexistent-tool",
          arguments: "{}"
        }
      }

      message = %{
        role: "assistant",
        tool_calls: [tool_call]
      }

      send(pid, message)

      Process.sleep(200)

      receive do
        [response] ->
          assert response[:id] == "call_invalid"
          assert response[:role] == "tool"
          assert response[:content] == "Invalid tool call. No tool named `nonexistent-tool`."
      after
        2000 ->
          flunk("Timed out waiting for invalid tool response")
      end
    end
  end

  describe "handle_info - Broadcast scenarios" do
    setup do
      defmodule BroadcastTerminalMockModule do
        @behaviour Weaver.Tools.Tool

        @impl true
        def definition() do
          %{
            type: "function",
            function: %{
              name: "broadcast-terminal-tool",
              description: "A terminal broadcast test tool",
              parameters: %{type: "object", properties: %{}}
            }
          }
        end

        @impl true
        def run(_tool_call) do
          {:terminal, "terminal data"}
        end
      end

      defmodule BroadcastNormalMockModule do
        @behaviour Weaver.Tools.Tool

        @impl true
        def definition() do
          %{
            type: "function",
            function: %{
              name: "broadcast-normal-tool",
              description: "A normal broadcast test tool",
              parameters: %{type: "object", properties: %{}}
            }
          }
        end

        @impl true
        def run(_tool_call) do
          "normal response"
        end
      end

      config = %Tools{
        base_dir: "/tmp/unused",
        tool_definitions: [
          %{
            type: "function",
            function: %{
              name: "broadcast-terminal-tool",
              description: "A terminal broadcast test tool",
              parameters: %{type: "object", properties: %{}}
            }
          },
          %{
            type: "function",
            function: %{
              name: "broadcast-normal-tool",
              description: "A normal broadcast test tool",
              parameters: %{type: "object", properties: %{}}
            }
          }
        ],
        tool_modules: %{
          "broadcast-terminal-tool" => BroadcastTerminalMockModule,
          "broadcast-normal-tool" => BroadcastNormalMockModule
        }
      }

      # Stop any existing server first
      stop_tools_server()
      Process.sleep(50)

      {:ok, pid} = Tools.start_link(config)

      on_exit(fn ->
        stop_tools_server()
      end)

      %{pid: pid}
    end

    test "terminal tool calls broadcast to commands topic", %{pid: pid} do
      subscribe(Weaver.PubSub, "commands")

      tool_call = %{
        id: "call_terminal_1",
        type: "function",
        function: %{
          name: "broadcast-terminal-tool",
          arguments: "{}"
        }
      }

      message = %{
        role: "assistant",
        tool_calls: [tool_call]
      }

      send(pid, message)

      Process.sleep(200)

      receive do
        {:terminal_tool_call, responses} ->
          assert length(responses) == 1
          assert hd(responses)[:id] == "call_terminal_1"
          assert hd(responses)[:role] == "tool"
          assert hd(responses)[:content] == {:terminal, "terminal data"}
      after
        2000 ->
          flunk("Timed out waiting for terminal tool broadcast to commands topic")
      end
    end

    test "non-terminal tool calls broadcast to messages topic", %{pid: pid} do
      subscribe(Weaver.PubSub, "messages")

      tool_call = %{
        id: "call_normal_1",
        type: "function",
        function: %{
          name: "broadcast-normal-tool",
          arguments: "{}"
        }
      }

      message = %{
        role: "assistant",
        tool_calls: [tool_call]
      }

      send(pid, message)

      Process.sleep(200)

      receive do
        [response] ->
          assert response[:id] == "call_normal_1"
          assert response[:role] == "tool"
          assert response[:content] == "normal response"
      after
        2000 ->
          flunk("Timed out waiting for non-terminal tool broadcast to messages topic")
      end
    end
  end

end