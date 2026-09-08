defmodule Weaver.Api.Bedrock do
  @moduledoc """
  Client for AWS Bedrock api. Built on https://ex-aws-bedrock.hexdocs.pm/ExAws.Bedrock.html

  ## Config

  | Key | Description | Default |
  |---|---|---|
  | `:credential_process` | A function that takes zero arguments and returns aws credentials. | |
  """

  @behaviour Weaver.Api

  def start_link(),
    do:
      DynamicSupervisor.start_child(
        Weaver.DynamicSupervisor,
        {Weaver.Api.Bedrock.Request,
         struct!(Weaver.Api.Bedrock.Request, Application.get_env(:weaver, :bedrock))}
      )

  def get_message_translator(updater) do
    fn req_resp ->
      parse_tool_calls(req_resp, updater)
      |> Map.update(:messages, [], fn msgs ->
        Enum.map(msgs, &translate_message(&1))
      end)
    end
  end

  def parse_tool_calls(
        resp = %{choices: [%{message: %{tool_calls: [%{function: %{arguments: _}} | _]}} | _]},
        updater
      ) do
    update_in(
      resp,
      [
        :choices,
        Access.all(),
        :message,
        :tool_calls,
        Access.all(),
        :function,
        :arguments
      ],
      updater
    )
  end

  def parse_tool_calls(req = %{messages: [%{role: _} | _]}, updater) do
    update_in(
      req,
      [
        :messages,
        Access.filter(fn el ->
          is_map_key(el, :tool_calls)
        end),
        :tool_calls,
        Access.all(),
        :function,
        :arguments
      ],
      updater
    )
  end

  def parse_tool_calls(any, _), do: any

  def translate_message(msg = %{role: "tool", id: id}), do: Map.put(msg, :tool_call_id, id)

  def translate_message(msg), do: msg

  def chat(data = %{model: model}) do
    tool_call_decoder =
      Weaver.Api.Bedrock.get_message_translator(&Jason.decode!(&1, keys: :atoms))

    tool_call_encoder = Weaver.Api.Bedrock.get_message_translator(&Jason.encode!/1)

    %{
      choices: [%{message: message}],
      usage: %{prompt_tokens: input_tokens, total_tokens: total_tokens}
    } =
      case ExAws.Bedrock.invoke_model(model, tool_call_encoder.(data))
           |> Weaver.Api.Bedrock.Request.request() do
        {:ok, response} ->
          response
          |> tool_call_decoder.()
      end

    %{
      message: message,
      input_tokens: input_tokens,
      total_tokens: total_tokens
    }
  end
end

defmodule Weaver.Api.BedrockMock do
  @moduledoc """
  Mock AWS Bedrock api
  """

  @behaviour Weaver.Api

  def start_link(), do: :ignore

  def chat(req = %{messages: messages}) do
    tool_call_encoder = Weaver.Api.Bedrock.get_message_translator(&Jason.encode!/1)

    tool_call_decoder =
      Weaver.Api.Bedrock.get_message_translator(&Jason.decode!(&1, keys: :atoms))

    tool_call_encoder.(req)

    %{
      choices: [%{message: message}],
      usage: %{prompt_tokens: input_tokens, total_tokens: total_tokens}
    } =
      File.read!(
        if List.last(messages, %{role: "assistant"})[:role] === "tool" do
          "dev/bedrock-response.json"
        else
          "dev/bedrock-tool-response.json"
        end
      )
      |> Jason.decode!(keys: :atoms)
      |> tool_call_decoder.()

    %{
      message: message,
      input_tokens: input_tokens,
      total_tokens: total_tokens
    }
  end
end
