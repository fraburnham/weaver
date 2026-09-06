defmodule Weaver.TUI.IO do
  use GenServer

  import Bitwise
  alias Weaver.TUI.Term
  alias Weaver.TUI.IO, as: WIO
  alias Weaver.TUI.ANSI

  defstruct caller: nil,
            buffer: [],
            original_term_config: nil,
            prompt_state: :not_prompting,
            prompt: nil

  @poll_delay 5

  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  @impl true
  def init(state = %WIO{}) do
    {:ok, term_config = %{c_lflag: c_lflag}} = Term.get_config()

    Term.set_config(%{
      term_config
      | c_lflag: set_flag(c_lflag, :ICANON, false) |> set_flag(:ECHOCTL, false)
    })

    # TODO: know size of terminal and get notified/check for updates (eventually)
    # Know the length of the prompt when it comes in. Use all that to know how many lines to clear

    {:ok,
     %WIO{state | buffer: [], original_term_config: term_config, prompt_state: :not_prompting}}
  end

  @impl true
  def terminate(_, %WIO{original_term_config: term_config}) do
    # TODO: This needs to be in a monitor or something. Lots of reasons to not gracefully stop a genserver...
    Term.set_config(term_config)
  end

  @impl true
  def handle_info(:poll_for_input, state = %WIO{prompt_state: prompt_state}) do
    # Delay the message to keep polling so other messages can squeeze in
    case prompt_state do
      :prompting -> Process.send_after(self(), :poll_for_input, @poll_delay)
      _ -> nil
    end

    case Term.attempt_read() do
      {:ok, c} -> {:noreply, handle_char(c, state)}
      _ -> {:noreply, state}
    end
  end

  #
  # public api handlers
  #

  @impl true
  def handle_call({:output, item}, _, state = %WIO{prompt_state: :not_prompting}),
    do: {:reply, IO.puts(item), state}

  @impl true
  def handle_call(
        {:output, item},
        _,
        state = %WIO{prompt_state: :prompting, prompt: prompt, buffer: buffer}
      ) do
    # TODO: handle more than one line of prompt
    output = [:line_erase_all, item, "\n", prompt, buffer]

    {:reply, IO.write(output), state}
  end

  @impl true
  def handle_call({:prompt, p}, {from, _}, state = %WIO{prompt_state: :not_prompting}) do
    send(self(), :poll_for_input)

    {:reply, IO.write(p),
     %WIO{state | caller: from, prompt_state: :prompting, buffer: [], prompt: p}}
  end

  @impl true
  def handle_call({:prompt, _}, _from, state = %WIO{prompt_state: ps}),
    do: {:reply, {:error, ps}, state}

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

  defp handle_char(c, state = %WIO{buffer: buffer, caller: caller}) do
    case c do
      c when c in [127, 8] ->
        # backspace
        # TODO: why do I have to double up? The control char must still be echoing something?
        [:cursor_backward, :cursor_backward, "  ", :cursor_backward, :cursor_backward]
        |> ANSI.format()
        |> IO.write()

        %WIO{state | buffer: List.first(buffer, [])}

      10 ->
        send(caller, {:keyboard_input, IO.chardata_to_string(buffer)})
        %WIO{state | buffer: [], prompt_state: :not_prompting}

      # Silently ignore control characters for now
      c when c < 32 ->
        state

      c ->
        %WIO{state | buffer: [buffer | [c]]}
    end
  end

  #
  # public api
  #

  def puts(item), do: GenServer.call(__MODULE__, {:output, item})

  def prompt(p), do: GenServer.call(__MODULE__, {:prompt, p})
end
