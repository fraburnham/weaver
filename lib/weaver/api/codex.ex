defmodule Weaver.Api.Codex do
  @moduledoc """
  Client for Codex responses api

  ## Config

  | Key | Description | Default |
  |---|---|---|
  | `:project` | Project id for accounting/tracking. | Pulled from `WEAVER_OPENAI_PROJECT` |
  | `:api_key` | Key for authenticating with openai api. Optional, if not provided oidc will be used. | Pulled from `WEAVER_OPENAI_API_KEY` |
  """

  alias Weaver.Api.Codex.Oidc

  @behaviour Weaver.Api

  @impl true
  def start_link(_), do: Oidc.start_link()

  @impl true
  def chat(context) do
    context = transform_context(context)

    tool_call_decoder =
      Weaver.Api.Bedrock.get_message_translator(&Jason.decode!(&1, keys: :atoms))

    %{project: project} =
      Application.get_env(:weaver, :openai) |> Enum.into(%{})

    api_key = get_api_key(Application.get_env(:weaver, :openai))

    req_options =
      [
        url: "https://chatgpt.com/backend-api/codex/responses",
        headers: %{"OpenAI-Project" => project, authorization: "Bearer #{api_key}"}
      ]
      |> Keyword.merge(Application.get_env(:weaver, :openai_req_options, []))

    Req.post!(
      req_options,
      json: context |> Map.put(:stream, true) |> Map.put(:store, false),
      receive_timeout: :infinity,
      decoders: [json: &Jason.decode(&1, keys: :atoms)]
    ).body
    |> extract_response()
    |> tool_call_decoder.()
  end

  defp get_api_key(%{api_key: api_key}) when is_binary(api_key), do: api_key

  defp get_api_key(_), do: Oidc.get_token()

  defp transform_context(context) do
    tool_call_encoder = Weaver.Api.Bedrock.get_message_translator(&Jason.encode!/1)

    context
    |> tool_call_encoder.()
    # TODO!! handle options and tools
    |> Map.drop([:messages, :options, :tools])
    |> Map.put(:input, context.messages)
  end

  defp extract_response(stream_body) do
    stream_body
    |> String.split("\n\n")
    |> List.foldl(%{message: [], input_tokens: 0, total_tokens: 0}, &process_event/2)
    |> update_in([:message], fn m -> %{role: "assistant", content: IO.iodata_to_binary(m)} end)
  end

  defp process_event(<<"event: response.output_text.delta\ndata: ", data::binary>>, acc) do
    delta =
      Jason.decode!(data)
      |> Map.get("delta")

    update_in(acc, [:message], fn m ->
      [m | delta]
    end)
  end

  defp process_event(<<"event: response.completed\ndata: ", data::binary>>, acc) do
    %{"response" => %{"usage" => %{"input_tokens" => i, "total_tokens" => t}}} = Jason.decode!(data)

    %{acc | input_tokens: i, total_tokens: t}
  end
  
  defp process_event(_, acc), do: acc
end
