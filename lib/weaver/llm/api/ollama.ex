defmodule Weaver.Api.Ollama do
  defp atomize_keys(l) when is_list(l) do
    Enum.map(l, &atomize_keys/1)
  end

  defp atomize_keys(m) when is_map(m) do
    Enum.map(m, &atomize_keys/1)
    |> Enum.into(%{})
  end

  defp atomize_keys({k, v}) when is_binary(k) do
    {String.to_atom(k), atomize_keys(v)}
  end

  defp atomize_keys(any) do
    any
  end

  def chat(context, %{base_url: base_url}) do
    # TODO: use response streaming
    # TODO: stop decoding and just use jason decode. should eliminate atomize_keys
    Req.post!(%URI{URI.parse(base_url) | path: "/api/chat"},
      json: Map.put(context, :stream, false),
      receive_timeout: :infinity
    ).body
    |> Map.take(["message", "prompt_eval_count", "eval_count"])
    |> atomize_keys()
  end
end

# TODO: what is the right way to organize this?
defmodule Weaver.Api.OllamaMock do
  def chat(_, _) do
    File.read!("dev/ollama-response.json")
    |> Jason.decode!(keys: :atoms)
    |> Map.take([:message, :prompt_eval_count, :eval_count])
  end
end
