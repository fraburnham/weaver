defmodule Weaver.LLM do
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @impl true
  def init(state) do
    Phoenix.PubSub.subscribe(Weaver.PubSub, "messages")

    {:ok, %{context: Weaver.LLM.Context.initial_context()}}
  end

  @doc "Messages from tool calls or user prompts have to be sent to the llm"
  @impl true
  def handle_info(msg = %{role: role}, state) when role in ["user", "tool"] do
    state = add_message(msg, state)
    response = request(state[:context])
    Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", response)
    {:noreply, add_message(response, state)}
  end

  @doc "Messages from the llm are already added to the context"
  @impl true
  def handle_info(msg = %{role: "assistant"}, state) do
    {:noreply, state}
  end

  @doc "Send a request to the api (using an api module)"
  defp request(context) do
    # TODO: Expect the api layer to return a single response w/ maybe some metadata about token usage
    # TODO: this fn owns reversing the message order

    # Mock response
    %{
      role: "assistant",
      content: "This is only a response."
    }
  end

  @doc "Add a message to the context"
  defp add_message(msg, state) do
    %{state | context: %{state[:context] | messages: [msg | state[:context][:messages]]}}
  end
end
