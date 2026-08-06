defmodule Weaver.Api.Ollama do
  defstruct base_url: nil

  def chat(context) do
    %{base_url: base_url} = Application.get_env(:weaver, :ollama)

    # TODO: use response streaming
    Req.post!(%URI{URI.parse(base_url) | path: "/api/chat"},
      json: Map.put(context, :stream, false),
      receive_timeout: :infinity,
      decode_json: [keys: :atoms]
    ).body
    |> Map.take([:message, :prompt_eval_count, :eval_count])

    # TODO: Rename prompt_eval_count -> input_tokens, eval_count -> total_tokens
  end
end

# TODO: what is the right way to organize this?
defmodule Weaver.Api.OllamaMock do
  def chat(%{messages: messages}) do
    # If the last message is a tool role then respond with a plain response
    # Else respond with a tool call response
    File.read!(
      if List.last(messages, %{role: "assistant"})[:role] === "tool" do
        "dev/ollama-response.json"
      else
        "dev/ollama-tool-response.json"
      end
    )
    |> Jason.decode!(keys: :atoms)
    |> Map.take([:message, :prompt_eval_count, :eval_count])

    # TODO: Rename prompt_eval_count -> input_tokens, eval_count -> total_tokens
  end
end
