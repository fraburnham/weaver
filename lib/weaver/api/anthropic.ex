defmodule Weaver.Api.Anthropic do
  @behaviour Weaver.Api

  defstruct api_key: nil,
            project: nil

  def start_link(), do: nil

  def translate_tool(%{function: %{name: name, description: description, parameters: parameters}}) do
    %{
      name: name,
      description: description,
      input_schema: parameters
    }
  end

  def message_to_anthropic(msg = %{role: "assistant", tool_calls: tool_calls})
      when not is_nil(tool_calls) do
    anthropic_message =
      case msg do
        %{thinking: thinking, thinking_signature: signature} ->
          %{
            role: "assistant",
            content: [%{type: "thinking", thinking: thinking, signature: signature}]
          }

        _ ->
          %{role: "assistant", content: []}
      end

    anthropic_message =
      case msg do
        %{content: text} ->
          Map.put(anthropic_message, :content, [
            %{type: "text", text: text} | anthropic_message[:content]
          ])

        _ ->
          anthropic_message
      end

    tool_calls =
      Enum.map(tool_calls, fn %{id: id, function: %{name: name, arguments: input}} ->
        %{
          id: id,
          name: name,
          input: input,
          type: "tool_use"
        }
      end)

    %{
      anthropic_message
      | content: List.flatten([tool_calls | anthropic_message[:content]]) |> Enum.reverse()
    }
  end

  def message_to_anthropic(%{role: "tool", id: id, content: content}) do
    %{
      role: "user",
      content: [
        %{
          tool_use_id: id,
          type: "tool_result",
          content: content
        }
      ]
    }
  end

  def message_to_anthropic(msg), do: msg

  def block_to_message(%{type: "text", text: text}, message) do
    Map.put(message, :content, text)
  end

  def block_to_message(%{type: "thinking", text: thinking, signature: signature}, message) do
    Map.put(message, :thinking, thinking)
    |> Map.put(:thinking_signature, signature)
  end

  def block_to_message(%{type: "tool_use", id: id, input: input, name: name}, message) do
    current_tool_calls = Map.get(message, :tool_calls, [])

    tool_call = %{
      id: id,
      function: %{
        name: name,
        arguments: input
      }
    }

    Map.put(message, :tool_calls, [tool_call | current_tool_calls])
  end

  def block_to_message(%{}, message), do: message

  defp isolate_system_prompt(messages) do
    List.foldl(messages, %{system: [], messages: []}, fn
      %{role: "system", content: text}, acc = %{system: system} ->
        %{acc | system: [%{type: "text", text: text} | system]}

      msg, acc = %{messages: messages} ->
        %{acc | messages: [msg | messages]}
    end)
  end

  def chat(%{model: model, messages: messages, tools: tools}) do
    %{api_key: api_key, project: project} =
      struct!(Weaver.Api.Anthropic, Application.get_env(:weaver, :anthropic))

    %{system: system, messages: messages} = isolate_system_prompt(messages)

    # TODO: region from config
    {:ok,
     %{
       content: blocks,
       role: "assistant",
       type: "message",
       usage: %{input_tokens: input_tokens, output_tokens: output_tokens}
     }} =
      Anthropix.init(api_key,
        base_url: "https://bedrock-mantle.us-east-1.api.aws/anthropic/v1",
        decode_json: [keys: :atoms],
        headers: [
          {"anthropic-version", "2023-06-01"},
          {"user-agent", "anthropix/v0.6.2-patch-2026-08-21"},
          {"anthropic-workspace-id", project}
        ]
      )
      |> Anthropix.chat(
        model: model,
        messages:
          List.foldl(messages, [], fn el, acc ->
            [Weaver.Api.Anthropic.message_to_anthropic(el) | acc]
          end),
        system: system,
        tools: Enum.map(tools, &Weaver.Api.Anthropic.translate_tool/1),
        thinking: %{type: "adaptive"}
      )

    %{
      message:
        Enum.reduce(blocks, %{role: "assistant"}, &Weaver.Api.Anthropic.block_to_message/2),
      input_tokens: input_tokens,
      total_tokens: input_tokens + output_tokens
    }
  end
end
