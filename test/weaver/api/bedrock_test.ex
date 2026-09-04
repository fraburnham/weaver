defmodule Weaver.Api.BedrockTest do
  use ExUnit.Case, async: true

  test "parse_tool_calls/2 internal -> bedrock" do
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
                arguments: %{input: "This is only a test."},
                id: "call_hvopf47w"
              }
            }
          ]
        }
      ]
    }

    %{messages: [%{tool_calls: [%{function: %{arguments: actual}}]}]} =
      Weaver.Api.Bedrock.parse_tool_calls(request, &Jason.encode!/1)

    expected = %{input: "This is only a test."} |> Jason.encode!()

    assert actual == expected
  end

  test "parse_tool_calls/2 bedrock -> internal" do
    response = %{
      choices: [
        %{
          message: %{
            tool_calls: [
              %{
                function: %{
                  arguments:
                    "{\"content\":\"My name is Frank.\",\"topic\":\"User name\",\"overwrite\":true}"
                }
              }
            ]
          }
        }
      ]
    }

    %{choices: [%{message: %{tool_calls: [%{function: %{arguments: actual}}]}}]} =
      Weaver.Api.Bedrock.parse_tool_calls(response, &Jason.decode!(&1, keys: :atoms))

    expected = %{content: "My name is Frank.", topic: "User name", overwrite: true}

    assert actual == expected
  end
end
