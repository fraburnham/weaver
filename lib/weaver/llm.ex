defmodule Weaver.LLM do
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @impl true
  def init(_) do
    Phoenix.PubSub.subscribe(Weaver.PubSub, "messages")

    {:ok, %{context: Weaver.LLM.Context.initial_context()}}
  end

  # Messages from tool calls or user prompts have to be sent to the llm
  @impl true
  def handle_info(msg = %{role: role}, state) when role in ["user", "tool"] do
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
  defp request(state) do
    # TODO: Expect the api layer to return a single response w/ maybe some metadata about token usage
    state[:context]
    |> context_to_api_context()
    |> Weaver.Api.Ollama.chat()
    |> Map.get(:message)
  end

  # Add a message to the context
  defp add_message(msg, state) do
    %{state | context: %{state[:context] | messages: [msg | state[:context][:messages]]}}
  end

  defp context_to_api_context(context) do
    %{context | messages: Enum.reverse(context[:messages])}
  end
end
