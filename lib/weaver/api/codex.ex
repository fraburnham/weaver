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

  @turn_skeleton %{role: "assistant", content: ""}

  @impl true
  def start_link(_), do: Oidc.start_link()

  @impl true
  def chat(context) do
    context = transform_context(context)

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
    |> transform_response()
  end

  defp get_api_key(%{api_key: api_key}) when is_binary(api_key), do: api_key

  defp get_api_key(_), do: Oidc.get_token()

  defp transform_context(context) do
    tool_call_encoder = Weaver.Api.Bedrock.get_message_translator(&Jason.encode!/1)

    context
    |> tool_call_encoder.()
    # TODO!! handle options
    |> Map.drop([:messages, :options])
    |> Map.put(:input, context.messages)
    |> update_in([:tools, Access.all()], fn t ->
      Map.drop(t, [:function])
      |> Map.merge(t.function)
    end)
    |> update_in([:input], fn inputs ->
      List.foldr(inputs, [], fn
        i = %{role: "assistant", tool_calls: tool_calls}, acc ->
          List.foldl(
            tool_calls,
            [Map.drop(i, [:tool_calls]) | acc],
            fn %{
                 function: %{
                   name: name,
                   arguments: arguments
                 },
                 id: id
               },
               acc ->
              [
                %{
                  arguments: Jason.encode!(arguments),
                  call_id: id,
                  name: name,
                  type: "function_call"
                }
                | acc
              ]
            end
          )

        i, acc ->
          [i | acc]
      end)
    end)
    |> update_in([:input, Access.all()], fn
      m = %{role: "tool", content: content, id: id} ->
        %{output: content, type: "function_call_output", call_id: id}

      m ->
        m
    end)
  end

  defp transform_response(stream_body) do
    stream_body
    |> String.split("\n\n")
    |> List.foldl(%{message: @turn_skeleton, input_tokens: 0, total_tokens: 0}, &process_event/2)
    |> update_in([:message, :content], fn
      m when is_nil(m) -> m
      m -> IO.iodata_to_binary(m)
    end)
  end

  defp process_event(<<"event: response.output_item.done\ndata: ", data::binary>>, acc) do
    Jason.decode!(data)
    |> process_item(acc)
  end

  defp process_event(<<"event: response.completed\ndata: ", data::binary>>, acc) do
    %{"response" => %{"usage" => %{"input_tokens" => i, "total_tokens" => t}}} =
      Jason.decode!(data)

    %{acc | input_tokens: i, total_tokens: t}
  end

  defp process_event(_, acc), do: acc

  defp process_item(%{"item" => %{"type" => "message", "content" => [content]}}, acc) do
    put_in(acc, [:message, :content], content["text"] || "")
  end

  defp process_item(
         %{
           "item" => %{
             "type" => "function_call",
             "name" => fn_name,
             "arguments" => arguments,
             "call_id" => id
           }
         },
         acc
       ) do
    update_in(acc, [:message, :tool_calls], fn tool_calls ->
      [
        %{function: %{name: fn_name, arguments: Jason.decode!(arguments)}, id: id}
        | tool_calls || []
      ]
    end)
  end
end

# TODO: handle reasoning
