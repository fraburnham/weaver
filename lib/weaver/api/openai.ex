defmodule Weaver.Api.OpenAI do
  @behaviour Weaver.Api

  # TODO: region from config
  @base_uri "https://bedrock-mantle.us-east-1.api.aws/openai"

  def start_link(), do: {:ok, nil}

  def chat(context) do
    # TODO: this can use a short term secret. should be generating it here, too
    # (but the UI one is 12h which is both short and long enough)
    %{api_key: api_key, project: project} =
      Application.get_env(:weaver, :openai) |> Enum.into(%{})

    tool_call_decoder = Weaver.Api.Bedrock.tool_call_parser(&Jason.decode!(&1, keys: :atoms))
    tool_call_encoder = Weaver.Api.Bedrock.tool_call_parser(&Jason.encode!/1)

    req_options =
      [
        url: "#{@base_uri}/v1/chat/completions",
        headers: %{"OpenAI-Project" => project, authorization: "Bearer #{api_key}"}
      ]
      |> Keyword.merge(Application.get_env(:weaver, :openai_req_options, []))

    # TODO: track prompt_cache_key!
    # TODO: support reasoning_effort
    %{
      choices: [%{message: message}],
      usage: %{prompt_tokens: input_tokens, total_tokens: total_tokens}
    } =
      Req.post!(
        req_options,
        json: tool_call_encoder.(context) |> Map.put(:stream, false) |> Map.put(:store, false),
        receive_timeout: :infinity,
        decoders: [json: &Jason.decode(&1, keys: :atoms)]
      ).body
      |> tool_call_decoder.()

    %{
      message: message,
      input_tokens: input_tokens,
      total_tokens: total_tokens
    }
  end
end
