defmodule Weaver.Api.BedrockTest do
  use ExUnit.Case, async: true

  test "parse_tool_calls/2 internal -> bedrock" do
    expected_arguments = %{input: "This is only a test."} |> Jason.encode!()
    expected_id = "call_hvopf47w"

    request = %{
      messages: [
        %{
          role: "assistant",
          content: "mock content",
          tool_calls: [
            %{
              function: %{
                index: 0,
                name: "mock",
                arguments: Jason.decode!(expected_arguments, keys: :atoms),
                id: expected_id
              }
            }
          ]
        }
      ]
    }

    %{
      messages: [
        %{tool_calls: [%{function: %{arguments: actual_arguments, tool_call_id: actual_id}}]}
      ]
    } =
      Weaver.Api.Bedrock.parse_tool_calls(request, &Jason.encode!/1)

    assert actual_arguments == expected_arguments
    assert actual_id == expected_id
  end

  test "parse_tool_calls/2 bedrock -> internal" do
    expected_arguments = %{content: "My name is Frank.", topic: "User name", overwrite: true}
    expected_id = "chatcmpl-tool-b3c80fa98276b0b2"

    response = %{
      choices: [
        %{
          message: %{
            tool_calls: [
              %{
                function: %{
                  arguments: Jason.encode!(expected_arguments),
                  id: expected_id
                }
              }
            ]
          }
        }
      ]
    }

    %{
      choices: [
        %{message: %{tool_calls: [%{function: %{arguments: actual_arguments, id: actual_id}}]}}
      ]
    } =
      Weaver.Api.Bedrock.parse_tool_calls(response, &Jason.decode!(&1, keys: :atoms))

    assert actual_arguments == expected_arguments
    assert actual_id == expected_id
  end
end
