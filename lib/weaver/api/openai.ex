defmodule Weaver.Api.OpenAI do
  @moduledoc """
  Client for OpenAI apis

  ## Config

  | Key | Description | Default |
  |---|---|---|
  | `:project` | Project id for accounting/tracking. | Pulled from `WEAVER_OPENAI_PROJECT` |
  | `:api_key` | Key for authenticating with openai api. | Pulled from `WEAVER_OPENAI_API_KEY` |
  """

  @behaviour Weaver.Api

  @base_uri "https://bedrock-mantle.us-east-1.api.aws/openai"

  @impl true
  def start_link(), do: :ignore

  @impl true
  def chat(context) do
    %{api_key: api_key, project: project} =
      Application.get_env(:weaver, :openai) |> Enum.into(%{})

    tool_call_decoder =
      Weaver.Api.Bedrock.get_message_translator(&Jason.decode!(&1, keys: :atoms))

    tool_call_encoder = Weaver.Api.Bedrock.get_message_translator(&Jason.encode!/1)

    req_options =
      [
        url: "#{@base_uri}/v1/chat/completions",
        headers: %{"OpenAI-Project" => project, authorization: "Bearer #{api_key}"}
      ]
      |> Keyword.merge(Application.get_env(:weaver, :openai_req_options, []))

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
