defmodule Weaver.TUI.IO do
  use GenServer

  import Bitwise
  alias Weaver.TUI.Term

  @poll_delay 5

  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  @impl true
  def init(_) do
    {:ok, config = %{c_lflag: c_lflag}} = Term.get_config()

    Term.set_config(%{config | c_lflag: set_flag(c_lflag, :ICANON, false)})

    send(self(), :poll_for_input)

    # Buffer should stay an iodata which means output should stay unmolested so IO.puts can work just fine
    {:ok, %{buffer: [], original_term_config: config}}
  end

  @impl true
  def terminate(_, %{original_term_config: config}) do
    # TODO: This needs to be in a monitor or something. Lots of reasons to not gracefully stop a genserver...
    Term.set_config(config)
  end

  @impl true
  def handle_info(:poll_for_input, state = %{buffer: buffer}) do
    # Delay the message to keep polling so other messages can squeeze in
    Process.send_after(self(), :poll_for_input, @poll_delay)

    case Term.attempt_read() do
      {:ok, ch} -> {:noreply, %{state | buffer: [buffer | [ch]]}}
      _ -> {:noreply, state}
    end
  end

  @impl true
  def handle_call(:get_buffer, _from, state = %{buffer: buffer}),
    do: {:reply, {:ok, buffer}, state}

  #
  # private
  #

  defp set_flag(bitfield, flag, enabled, flag_mapping) do
    flag_value = Map.get(flag_mapping, flag)

    if enabled do
      bitfield &&& flag_value
    else
      bitfield &&& bnot(flag_value)
    end
  end

  defp set_flag(bitfield, flag, enabled),
    do: set_flag(bitfield, flag, enabled, Term.get_flag_values())

  #
  # public
  #

  def get_buffer do
    GenServer.call(__MODULE__, :get_buffer)
  end
end
