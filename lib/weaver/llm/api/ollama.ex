defmodule Weaver.Api.Ollama do
  defp atomize_keys(l) when is_list(l) do
    Enum.map(l, &atomize_keys/1)
  end

  defp atomize_keys(m) when is_map(m) do
    Enum.map(m, &atomize_keys/1)
    |> Enum.into(%{})
  end

  defp atomize_keys({k, v}) do
    {String.to_atom(k), atomize_keys(v)}
  end

  defp atomize_keys(any) do
    any
  end

  def chat(context) do
    # TODO: use response streaming
    Req.post!("http://workload.api.llm.skynet/api/chat",
      json: Map.put(context, :stream, false),
      receive_timeout: :infinity
    ).body
    |> Map.take(["message", "prompt_eval_count", "eval_count"])
    |> atomize_keys()
  end
end
