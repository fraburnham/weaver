defmodule Weaver.History do
  use GenServer

  alias Weaver.History

  defstruct base_dir: nil

  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  @impl true
  def init(%History{base_dir: base_dir}) do
    history_file_path =
      [base_dir, "#{DateTime.to_iso8601(DateTime.utc_now())}.jsonl"]
      |> Path.join()
      |> Path.expand()

    File.mkdir_p!(base_dir |> Path.expand())
    {:ok, file_descriptor} = File.open(history_file_path, [:append])

    Phoenix.PubSub.subscribe(Weaver.PubSub, "messages")

    {:ok, file_descriptor}
  end

  @impl true
  def handle_info(msg = %{role: _role}, file_descriptor) do
    update_file(file_descriptor, msg)

    {:noreply, file_descriptor}
  end

  @impl true
  def handle_info(msgs = [%{role: _} | _], file_descriptor) do
    for msg <- msgs, do: update_file(file_descriptor, msg)

    {:noreply, file_descriptor}
  end

  @impl true
  def terminate(_reason, file_descriptor) do
    File.close(file_descriptor)
  end

  defp update_file(file_descriptor, msg) do
    IO.puts(file_descriptor, Jason.encode_to_iodata!(msg))
  end
end
