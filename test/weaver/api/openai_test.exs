defmodule Weaver.Api.OpenAITest do
  use ExUnit.Case, async: true

  describe "chat/1" do
    test "happy path: standard text completion" do
      Req.Test.stub(OpenAIMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/openai/v1/chat/completions"

        body = Jason.decode!(Req.Test.raw_body(conn), keys: :atoms)
        assert body.stream == false
        assert body.store == false
        assert Enum.member?(body.messages, %{role: "user", content: "Hello!"})

        Req.Test.json(conn, %{
          "choices" => [%{"message" => %{"role" => "assistant", "content" => "Hello"}}],
          "usage" => %{"prompt_tokens" => 10, "total_tokens" => 20}
        })
      end)

      context = %{messages: [%{role: "user", content: "Hello!"}]}
      result = Weaver.Api.OpenAI.chat(context)

      assert result.message == %{role: "assistant", content: "Hello"}
      assert result.input_tokens == 10
      assert result.total_tokens == 20
    end
    test "tool calls response" do
      Req.Test.stub(OpenAIMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/openai/v1/chat/completions"

        Req.Test.json(conn, %{
          "choices" => [
            %{
              "message" => %{
                "role" => "assistant",
                "content" => nil,
                "tool_calls" => [
                  %{
                    "id" => "call_123",
                    "type" => "function",
                    "function" => %{
                      "name" => "get_weather",
                      "arguments" => "{\"location\": \"Boston\"}"
                    }
                  }
                ]
              }
            }
          ],
          "usage" => %{"prompt_tokens" => 15, "total_tokens" => 25}
        })
      end)

      context = %{messages: [%{role: "user", content: "What's the weather in Boston?"}]}
      result = Weaver.Api.OpenAI.chat(context)

      assert result.message.role == "assistant"
      assert result.message.tool_calls != nil
      tool_call = Enum.at(result.message.tool_calls, 0)
      assert tool_call.function.name == "get_weather"
      assert result.input_tokens == 15
      assert result.total_tokens == 25
    end
  end
end