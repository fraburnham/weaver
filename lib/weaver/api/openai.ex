defmodule Weaver.Api.OpenAI do
  @behaviour Weaver.Api

  # TODO: region from config
  @base_uri URI.parse("https://bedrock-mantle.us-east-2.api.aws/")

  def start_link(), do: nil

  def chat(context) do
    # TODO: this can use a short term secret. should be generating it here, too
    # (but the UI one is 12h which is both short and long enough)
    api_key = Application.get_env(:weaver, :openai)

    tool_call_decoder = Weaver.Api.Bedrock.tool_call_parser(&Jason.decode!/1)
    tool_call_encoder = Weaver.Api.Bedrock.tool_call_parser(&Jason.encode!/1)

    # TODO: track prompt_cache_key!
    # TODO: support reasoning_effort
    %{
      choices: [%{message: message}],
      usage: %{prompt_tokens: input_tokens, total_tokens: total_tokens}
    } =
      Req.post!(
        [
          url: %URI{@base_uri | path: "/v1/chat/completions"},
          headers: %{authorization: "Bearer #{api_key}"}
        ],
        json: tool_call_encoder.(context) |> Map.put(:stream, false) |> Map.put(:store, false),
        receive_timeout: :infinity,
        decode_json: [keys: :atoms]
      ).body
      |> tool_call_decoder.()

    %{
      message: message,
      input_tokens: input_tokens,
      total_tokens: total_tokens
    }
  end
end
