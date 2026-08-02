defmodule Weaver.LLM do
  use GenServer
  alias Weaver.LLM

  defstruct model: nil, api: nil, base_url: nil, context: nil

  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  @impl true
  def init(config = %LLM{model: model, api: _, base_url: _}) do
    Phoenix.PubSub.subscribe(Weaver.PubSub, "messages")

    {:ok, %LLM{config | context: Weaver.LLM.Context.initial_context(%{model: model})}}
  end

  # Messages from tool calls or user prompts have to be sent to the llm
  @impl true
  def handle_info(msg = %{role: role}, state = %LLM{}) when role in ["user", "tool"] do
    state = add_message(msg, state)
    response = request(state)
    Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", response)
    {:noreply, add_message(response, state)}
  end

  # Messages from the llm are already added to the context
  @impl true
  def handle_info(%{role: "assistant"}, state) do
    {:noreply, state}
  end

  # Send a request to the api (using an api module)
  defp request(%LLM{context: context, base_url: base_url, api: api}) do
    context
    |> context_to_api_context()
    |> api.chat(%{base_url: base_url})
    |> Map.get(:message)
  end

  # Add a message to the context
  defp add_message(msg, state = %LLM{}) do
    %LLM{state | context: %{state.context | messages: [msg | state.context[:messages]]}}
  end

  defp context_to_api_context(context) do
    %{context | messages: Enum.reverse(context[:messages])}
  end
end
