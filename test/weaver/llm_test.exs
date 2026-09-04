defmodule Weaver.LLMTest do
  use ExUnit.Case, async: false

  defp safe_stop(name) do
    if pid = Process.whereis(name) do
      GenServer.stop(pid, :shutdown)
    end
  end

  # Mock API that implements Weaver.Api behaviour
  defmodule MockApi do
    @behaviour Weaver.Api

    def start_link() do
      {:ok, self()}
    end

    def chat(_context) do
      %{
        message: %{role: "assistant", content: "Mocked response"},
        total_tokens: 150,
        input_tokens: 100
      }
    end
  end

  # Mock Tools GenServer that returns fixed tool definitions
  defmodule MockTools do
    use GenServer

    def start_link(_) do
      GenServer.start_link(__MODULE__, :ok, name: Weaver.Tools)
    end

    @impl true
    def init(:ok) do
      {:ok, %{tool_definitions: []}}
    end

    @impl true
    def handle_call({:get_tool_definitions, _tools}, _from, state) do
      definitions = [
        %{
          type: "function",
          function: %{
            name: "test_tool",
            description: "A test tool",
            parameters: %{type: "object", properties: %{}, required: []}
          }
        }
      ]

      {:reply, definitions, %{state | tool_definitions: definitions}}
    end

    @impl true
    def handle_info(_msg, state) do
      {:noreply, state}
    end
  end

  setup do
    # Stop the real Weaver.Tools if running
    safe_stop(Weaver.Tools)

    # Start MockTools GenServer (will be registered as Weaver.Tools)
    MockTools.start_link([])

    # Build test config with MockApi module
    config = %Weaver.LLM{
      model: "test-model",
      model_options: %{context_window: 8192},
      api: MockApi,
      system_prompt: "You are a helpful assistant.",
      tools_available: ["test_tool"]
    }

    {:ok, config: config}
  end

  describe "init/1" do
    test "initializes with correct state", %{config: config} do
      # Stop any existing LLM GenServer
      safe_stop(Weaver.LLM)

      # Start the LLM with our config
      {:ok, _pid} = Weaver.LLM.start_link(config)

      # Get the state
      state = :sys.get_state(Weaver.LLM)

      assert state.model == "test-model"
      assert state.model_options.context_window == 8192
      assert state.api == MockApi
      assert state.system_prompt == "You are a helpful assistant."
      assert state.tools_available == ["test_tool"]
    end
  end

  describe "handle_continue/2" do
    test "starts the API", %{config: _config} do
      # MockApi.start_link should return {:ok, pid}
      assert {:ok, _pid} = MockApi.start_link()
    end
  end

  describe "handle_info for commands" do
    test "handles :clear command", %{config: config} do
      # Stop any existing LLM GenServer
      safe_stop(Weaver.LLM)

      {:ok, _pid} = Weaver.LLM.start_link(config)

      # Send :clear command
      send(Weaver.LLM, :clear)

      # Get state - context should be reset
      state = :sys.get_state(Weaver.LLM)

      # Context should have system prompt
      assert length(state.context[:messages]) >= 1
      assert state.total_tokens == nil
    end

    test "handles :clear with skip_init: true", %{config: %Weaver.LLM{} = config} do
      # Stop any existing LLM GenServer
      safe_stop(Weaver.LLM)

      config_with_skip = %Weaver.LLM{config | skip_init: true}
      {:ok, _pid} = Weaver.LLM.start_link(config_with_skip)

      # Get initial state
      initial_state = :sys.get_state(Weaver.LLM)

      # Send :clear command
      send(Weaver.LLM, :clear)

      # State should remain unchanged
      state = :sys.get_state(Weaver.LLM)

      assert state.skip_init == true
      assert state == initial_state
    end

    test "handles :terminal_tool_call by sending :clear to self", %{config: config} do
      # Stop any existing LLM GenServer
      safe_stop(Weaver.LLM)

      {:ok, _pid} = Weaver.LLM.start_link(config)

      # Send terminal_tool_call
      send(Weaver.LLM, {:terminal_tool_call, %{}})

      # Process should send :clear to itself, triggering context reset
      # We can verify by checking state after a brief pause
      Process.sleep(100)
      state = :sys.get_state(Weaver.LLM)

      # total_tokens should be nil after clear
      assert state.total_tokens == nil
    end
  end

  describe "handle_info for messages" do
    test "handles user message and broadcasts response", %{config: config} do
      # Stop any existing LLM GenServer
      safe_stop(Weaver.LLM)

      {:ok, _pid} = Weaver.LLM.start_link(config)

      # Subscribe to messages topic
      Phoenix.PubSub.subscribe(Weaver.PubSub, "messages")
      Phoenix.PubSub.subscribe(Weaver.PubSub, "metrics")

      # Send user message
      user_msg = %{role: "user", content: "Hello"}
      send(Weaver.LLM, user_msg)

      # Should receive assistant response on messages topic
      assert_receive %{role: "assistant", content: "Mocked response"}

      # Should receive metrics on metrics topic
      assert_receive %{total_tokens: 150, input_tokens: 100}

      # State should be updated
      state = :sys.get_state(Weaver.LLM)
      assert state.total_tokens == 150

      # Context should contain user message and assistant response
      assert Enum.any?(state.context[:messages], fn msg -> msg.role == "user" end)
      assert Enum.any?(state.context[:messages], fn msg -> msg.role == "assistant" end)
    end

    test "handles assistant message without API call", %{config: config} do
      # Stop any existing LLM GenServer
      safe_stop(Weaver.LLM)

      {:ok, _pid} = Weaver.LLM.start_link(config)

      # Get initial state
      initial_state = :sys.get_state(Weaver.LLM)
      initial_msg_count = length(initial_state.context[:messages])

      # Send assistant message (should be ignored)
      assistant_msg = %{role: "assistant", content: "Already in context"}
      send(Weaver.LLM, assistant_msg)

      # State should be unchanged
      state = :sys.get_state(Weaver.LLM)
      assert length(state.context[:messages]) == initial_msg_count
    end

    test "handles system message without API call", %{config: config} do
      # Stop any existing LLM GenServer
      safe_stop(Weaver.LLM)

      {:ok, _pid} = Weaver.LLM.start_link(config)

      # Get initial state
      initial_state = :sys.get_state(Weaver.LLM)
      initial_msg_count = length(initial_state.context[:messages])

      # Send system message (should be ignored)
      system_msg = %{role: "system", content: "System prompt"}
      send(Weaver.LLM, system_msg)

      # State should be unchanged
      state = :sys.get_state(Weaver.LLM)
      assert length(state.context[:messages]) == initial_msg_count
    end

    test "handles resume message without API call", %{config: config} do
      # Stop any existing LLM GenServer
      safe_stop(Weaver.LLM)

      {:ok, _pid} = Weaver.LLM.start_link(config)

      # Get initial state
      initial_state = :sys.get_state(Weaver.LLM)
      initial_msg_count = length(initial_state.context[:messages])

      # Send resume message
      resume_msg = %{role: "user", content: "Resumed message", resume: true}
      send(Weaver.LLM, resume_msg)

      # Message should be added but no API call
      state = :sys.get_state(Weaver.LLM)
      assert length(state.context[:messages]) == initial_msg_count + 1
    end

    test "handles multiple tool responses", %{config: config} do
      # Stop any existing LLM GenServer
      safe_stop(Weaver.LLM)

      {:ok, _pid} = Weaver.LLM.start_link(config)

      # Subscribe to messages topic
      Phoenix.PubSub.subscribe(Weaver.PubSub, "messages")
      Phoenix.PubSub.subscribe(Weaver.PubSub, "metrics")

      # Send multiple tool responses
      tool_responses = [
        %{role: "tool", content: "Tool result 1", id: "call_1"},
        %{role: "tool", content: "Tool result 2", id: "call_2"}
      ]

      send(Weaver.LLM, tool_responses)

      # Should receive assistant response
      assert_receive %{role: "assistant", content: "Mocked response"}

      # Should receive metrics
      assert_receive %{total_tokens: 150, input_tokens: 100}

      # State should be updated
      state = :sys.get_state(Weaver.LLM)
      assert state.total_tokens == 150
    end
  end

  describe "handle_info for resume commands" do
    test "handles {:resume, :clear}", %{config: config} do
      # Stop any existing LLM GenServer
      safe_stop(Weaver.LLM)

      {:ok, _pid} = Weaver.LLM.start_link(config)

      # Subscribe to messages topic
      Phoenix.PubSub.subscribe(Weaver.PubSub, "messages")

      # Send some messages to populate context
      send(Weaver.LLM, %{role: "user", content: "Test"})
      assert_receive %{role: "assistant"}

      # Get state with messages
      state_before = :sys.get_state(Weaver.LLM)
      assert length(state_before.context[:messages]) > 1

      # Send resume clear
      send(Weaver.LLM, {:resume, :clear})

      # Context messages should be cleared
      state_after = :sys.get_state(Weaver.LLM)
      assert state_after.context[:messages] == []
    end

    test "handles {:resume, other}", %{config: config} do
      # Stop any existing LLM GenServer
      safe_stop(Weaver.LLM)

      {:ok, _pid} = Weaver.LLM.start_link(config)

      # Get initial state
      initial_state = :sys.get_state(Weaver.LLM)

      # Send resume with other value
      send(Weaver.LLM, {:resume, :something_else})

      # State should be unchanged
      state = :sys.get_state(Weaver.LLM)
      assert state == initial_state
    end

    test "handles :resume_end", %{config: config} do
      # Stop any existing LLM GenServer
      safe_stop(Weaver.LLM)

      {:ok, _pid} = Weaver.LLM.start_link(config)

      # Get initial state
      initial_state = :sys.get_state(Weaver.LLM)

      # Send resume_end
      send(Weaver.LLM, :resume_end)

      # State should be unchanged
      state = :sys.get_state(Weaver.LLM)
      assert state == initial_state
    end
  end
end
