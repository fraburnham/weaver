defmodule Weaver.TUI do
  use GenServer

  def start_link(_args), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @impl true
  def init(_state) do
    Phoenix.PubSub.subscribe(Weaver.PubSub, "messages")

    header()
    prompt()

    {:ok, %{}}
  end

  # TODO: display tool calls

  # A message from the assistant without any tool calls means the assistant is ready for user input again
  @impl true
  def handle_info(msg = %{role: "assistant"}, state) do
    show_thinking(msg)
    show_content(msg)
    prompt()

    {:noreply, state}
  end

  @impl true
  def handle_info(%{role: _role}, state) do
    {:noreply, state}
  end

  # Display a prompt and broadcast the user input
  @impl true
  def handle_info(:prompt, state) do
    [:red, "> "]
    |> IO.ANSI.format()
    |> IO.gets()
    |> String.trim()
    |> user_input()

    {:noreply, state}
  end

  defp header do
    [:bright, "Type '/exit' to quit"]
    |> IO.ANSI.format()
    |> output()
  end

  defp prompt do
    send(self(), :prompt)
  end

  defp output(content) do
    IO.puts("")
    IO.puts(content)
    IO.puts("")
  end

  # TODO: make showing thinking optional
  defp show_thinking(%{thinking: thinking}),
    do: [:faint, :cyan, thinking] |> IO.ANSI.format() |> output()

  defp show_thinking(_), do: nil

  defp show_content(%{content: content}), do: Marcli.render(content) |> output()

  defp user_input("/exit") do
    System.stop(0)
    Process.sleep(:infinity)
  end

  defp user_input(<<"/", command::binary>>) do
    [:bright, :red, "Unknown command: ", command]
    |> IO.ANSI.format()
    |> output()

    prompt()
  end

  # If the user input wasn't a slash command broadcast it
  defp user_input(content) do
    Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", %{
      role: "user",
      content: content
    })
  end
end
