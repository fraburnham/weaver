defmodule Weaver.Api.Ollama do
  @moduledoc """
  Ollama api client
  """

  @behaviour Weaver.Api

  defstruct base_url: nil

  def start_link(), do: nil

  def chat(context) do
    %{base_url: base_url} = struct!(Weaver.Api.Ollama, Application.get_env(:weaver, :ollama))

    # TODO: use response streaming
    %{message: message, prompt_eval_count: input_tokens, eval_count: output_tokens} =
      Req.post!(%URI{URI.parse(base_url) | path: "/api/chat"},
        json: Map.put(context, :stream, false),
        receive_timeout: :infinity,
        decoders: [json: &Jason.decode(&1, keys: :atoms)]
      ).body
      |> Map.take([:message, :prompt_eval_count, :eval_count])

    %{
      message: message,
      input_tokens: input_tokens,
      total_tokens: input_tokens + output_tokens
      # TODO: total_tokens is definitely wrong...
    }
  end
end

defmodule Weaver.Api.OllamaMock do
  @moduledoc """
  Mock Ollama api client
  """

  @behaviour Weaver.Api

  def start_link(), do: nil

  def chat(%{messages: messages}) do
    # If the last message is a tool role then respond with a plain response
    # Else respond with a tool call response
    %{message: message, prompt_eval_count: input_tokens, eval_count: output_tokens} =
      File.read!(
        if List.last(messages, %{role: "assistant"})[:role] === "tool" do
          "dev/ollama-response.json"
        else
          "dev/ollama-tool-mock-response.json"
        end
      )
      |> Jason.decode!(keys: :atoms)
      |> Map.take([:message, :prompt_eval_count, :eval_count])

    %{
      message: message,
      input_tokens: input_tokens,
      total_tokens: input_tokens + output_tokens
    }
  end
end
