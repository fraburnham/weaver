defmodule Weaver.TUI do
  use GenServer

  def start_link(_args), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @impl true
  def init(state) do
    header()
    prompt()
    {:ok, state}
  end

  @impl true
  def handle_info(:update_display, state) do
    {:noreply, state}
  end

  def header do
    IO.puts(IO.ANSI.format([:bright, "\nType '/exit' to quit\n"]))
  end

  def prompt do
    IO.gets(IO.ANSI.format([:red, "> "]))
  end
end
