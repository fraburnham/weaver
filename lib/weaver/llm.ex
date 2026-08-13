defmodule Weaver.LLM do
  @moduledoc """
  `Weaver.LLM` ties together the API and message queue by maintaining conversation context with system prompt
  and message history, calling the API for each LLM turn, and broadcasting responses to all subscribers.
  """

  use GenServer
  alias Weaver.LLM
  alias Weaver.Tools

  defstruct model: nil,
            api: nil,
            context: nil,
            system_prompt: nil,
            tools_available: nil

  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  @impl true
  def init(config = %LLM{model: _, api: api, system_prompt: _, tools_available: _}) do
    api.start_link()

    Phoenix.PubSub.subscribe(Weaver.PubSub, "messages")
    Phoenix.PubSub.subscribe(Weaver.PubSub, "commands")

    Phoenix.PubSub.broadcast(Weaver.PubSub, "commands", :clear)

    {:ok, config}
  end

  @impl true
  def handle_info(:clear, state = %LLM{}) do
    {:noreply, %LLM{state | context: initial_context(state)}}
  end

  # When resuming don't add the initial state, it'll come over the "messages" topic
  @impl true
  def handle_info({:resume, :clear}, state = %LLM{}) do
    {:noreply, %LLM{state | context: %{initial_context(state) | messages: []}}}
  end

  @impl true
  def handle_info({:resume, _}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:resume_end, state) do
    # TODO: Will need a way to detect whose turn it is and possibly send the context to the llm
    {:noreply, state}
  end

  # Handle messages sent during the resume process
  @impl true
  def handle_info(msg = %{resume: true}, state = %LLM{}) do
    {:noreply, add_message(state, msg)}
  end

  # Messages from tool calls or user prompts have to be sent to the llm
  @impl true
  def handle_info(msg = %{role: role}, state = %LLM{}) when role in ["user", "tool"] do
    state = add_message(state, msg)
    response = request(state)
    Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", response)
    {:noreply, add_message(state, response)}
  end

  # Sometimes multiple tools are called in a single turn
  @impl true
  def handle_info(tool_responses = [%{role: role} | _], state) when role in ["tool"] do
    state = List.foldr(tool_responses, state, fn resp, acc -> add_message(acc, resp) end)
    response = request(state)
    Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", response)
    {:noreply, add_message(state, response)}
  end

  # Messages from the llm are already added to the context
  @impl true
  def handle_info(%{role: role}, state) when role in ["assistant", "system"] do
    {:noreply, state}
  end

  # Send a request to the api (using an api module)
  defp request(%LLM{context: context, api: api}) do
    context
    |> context_to_api_context()
    |> api.chat()
    |> Map.get(:message)
  end

  # Add a message to the context
  defp add_message(state = %LLM{}, msg) do
    %LLM{state | context: %{state.context | messages: [msg | state.context[:messages]]}}
  end

  defp context_to_api_context(context) do
    %{context | messages: Enum.reverse(context[:messages])}
  end

  defp initial_context(%LLM{
         model: model,
         system_prompt: system_prompt,
         tools_available: tools_available
       }) do
    system_prompt = %{
      role: "system",
      content: system_prompt
    }

    Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", system_prompt)

    %{
      model: model,
      messages: [system_prompt],
      tools: Tools.get_tool_definitions(tools_available)
    }
  end
end
