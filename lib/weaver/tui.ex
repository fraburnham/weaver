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
  def handle_info(%{role: "assistant", content: content}, state) do
    IO.puts("")
    IO.puts(Marcli.render(content))
    IO.puts("")

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
    IO.ANSI.format([:red, "> "])
    |> IO.gets()
    |> String.trim()
    |> user_input()

    {:noreply, state}
  end

  def header do
    [:bright, "\nType '/exit' to quit\n"]
    |> IO.ANSI.format()
    |> IO.puts()
  end

  def prompt do
    send(self(), :prompt)
  end

  defp user_input("/exit") do
    System.stop(0)
    Process.sleep(:infinity)
  end

  # If the user input wasn't a slash command broadcast it
  defp user_input(content) do
    Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", %{
      role: "user",
      content: content
    })
  end
end
