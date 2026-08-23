defmodule Weaver.TUI.IO do
  use GenServer
  import Bitwise

  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

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
    do: set_flag(bitfield, flag, enabled, Weaver.TUI.Term.get_flag_values())

  @impl true
  def init(_) do
    {:ok, config = %{c_lflag: c_lflag}} = Weaver.TUI.Term.get_config()

    Weaver.TUI.Term.set_config(%{config | c_lflag: set_flag(c_lflag, :ICANON, false)})

    # Buffer should stay an iodata which means output should stay unmolested so IO.puts can work just fine
    {:ok, %{buffer: [], original_term_config: config}}
  end

  @impl true
  def terminate(_, %{original_term_config: config}) do
    Weaver.TUI.Term.set_config(config)
  end
end
