defmodule Weaver.LLM do
  @moduledoc """
  Maintains conversation context and manages LLM interactions.

  `Weaver.LLM` ties together the API and messages topic by:
  - Maintaining conversation context with system prompt and message history
  - Calling the API for each LLM turn
  - Broadcasting responses to all subscribers

  ## Configuration

      config :weaver,
        llm: [api: Elixir.Module.That.Implements.Weaver.Api]

  | Key | Description |
  |-----|------|
  | `:api` | An elixir module that implements the `Weaver.Api` behaviour |
  """

  use GenServer, restart: :transient
  alias Weaver.LLM
  alias Weaver.Tools

  defstruct model: nil,
            context_window: nil,
            api: nil,
            context: nil,
            system_prompt: nil,
            tools_available: nil,
            total_tokens: nil,
            skip_init: false

  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  @impl true
  def init(config = %LLM{model: _, api: _, system_prompt: _, tools_available: _}) do
    Phoenix.PubSub.subscribe(Weaver.PubSub, "messages")
    Phoenix.PubSub.subscribe(Weaver.PubSub, "commands")

    Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", :clear)

    {:ok, config, {:continue, :start_api}}
  end

  @impl true
  def handle_continue(:start_api, config = %LLM{api: api}) do
    # TODO: this should fail if the child fails to start
    {:ok, _} = api.start_link()

    {:noreply, config}
  end

  #
  # "commands" handlers
  #

  @impl true
  def handle_info({:terminal_tool_call, _}, state) do
    send(self(), :clear)

    {:noreply, state}
  end

  @impl true
  def handle_info(:clear, state = %LLM{skip_init: true}), do: {:noreply, state}

  @impl true
  def handle_info(:clear, state = %LLM{}) do
    {:noreply, %LLM{state | context: initial_context(state), total_tokens: nil}}
  end

  @impl true
  def handle_info(:compact, state = %LLM{}) do
    %{message: summary} =
      %LLM{state | context: %{state.context | tools: nil}}
      |> add_message(%{
        role: "user",
        content:
          "Summarize our conversation so far. Include enough detail that a fresh agent would be able to pick up in the middle of this conversation."
      })
      |> request()

    initial_context = initial_context(state)

    Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", :clear)

    initial_context[:messages]
    |> Enum.each(fn msg -> Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", msg) end)

    Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", summary)

    {:noreply,
     %LLM{state | context: initial_context, skip_init: true}
     |> add_message(summary)}
  end

  # When resuming don't add the initial state, it'll come over the "messages" topic
  @impl true
  def handle_info({:resume, :clear}, state = %LLM{}) do
    {:noreply, %LLM{state | context: %{initial_context(state) | messages: []}}}
  end

  @impl true
  def handle_info({:resume, _}, state), do: {:noreply, state}

  @impl true
  def handle_info(:resume_end, state) do
    # TODO: Will need a way to detect whose turn it is and possibly send the context to the llm
    {:noreply, state}
  end

  #
  # "messages" handlers
  #

  # Handle messages sent during the resume process
  @impl true
  def handle_info(msg = %{resume: true}, state = %LLM{}), do: {:noreply, add_message(state, msg)}

  # Messages from tool calls or user prompts have to be sent to the llm
  @impl true
  def handle_info(msg = %{role: role}, state = %LLM{}) when role in ["user", "tool"] do
    state = add_message(state, msg)
    %{message: response, total_tokens: total_tokens, input_tokens: input_tokens} = request(state)
    Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", response)

    Phoenix.PubSub.broadcast(Weaver.PubSub, "metrics", %{
      total_tokens: total_tokens,
      input_tokens: input_tokens
    })

    {:noreply, add_message(state, response) |> add_context_usage(total_tokens)}
  end

  # Sometimes multiple tools are called in a single turn
  @impl true
  def handle_info(tool_responses = [%{role: "tool"} | _], state) do
    state = List.foldr(tool_responses, state, fn resp, acc -> add_message(acc, resp) end)
    %{message: response, total_tokens: total_tokens, input_tokens: input_tokens} = request(state)
    Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", response)

    Phoenix.PubSub.broadcast(Weaver.PubSub, "metrics", %{
      total_tokens: total_tokens,
      input_tokens: input_tokens
    })

    {:noreply, add_message(state, response) |> add_context_usage(total_tokens)}
  end

  # Messages from the llm are already added to the context
  @impl true
  def handle_info(%{role: role}, state) when role in ["assistant", "system"],
    do: {:noreply, state}

  # Send a request to the api (using an api module)
  defp request(%LLM{context: context, api: api}) do
    context
    |> context_to_api_context()
    |> api.chat()
  end

  # Add a message to the context
  defp add_message(state = %LLM{}, msg) do
    %LLM{state | context: %{state.context | messages: [msg | state.context[:messages]]}}
  end

  defp add_context_usage(state = %LLM{}, total_tokens) do
    %LLM{state | total_tokens: total_tokens}
  end

  defp context_to_api_context(context) do
    %{context | messages: Enum.reverse(context[:messages])}
  end

  defp initial_context(%LLM{
         model: model,
         system_prompt: system_prompt,
         tools_available: tools_available,
         context_window: context_window
       }) do
    system_prompt = %{
      role: "system",
      content: system_prompt
    }

    Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", system_prompt)

    %{
      model: model,
      messages: [system_prompt],
      tools: Tools.get_tool_definitions(tools_available),
      options: %{
        num_ctx: context_window
      }
    }
  end
end
