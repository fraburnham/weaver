defmodule Weaver.Api.Ollama do
  def chat(context, %{base_url: base_url}) do
    # TODO: use response streaming
    Req.post!(%URI{URI.parse(base_url) | path: "/api/chat"},
      json: Map.put(context, :stream, false),
      receive_timeout: :infinity,
      decode_json: [keys: :atoms]
    ).body
    |> Map.take([:message, :prompt_eval_count, :eval_count])
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
