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

    test "request payload validation" do
      Req.Test.stub(OpenAIMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/openai/v1/chat/completions"

        raw_body = Req.Test.raw_body(conn)
        body = Jason.decode!(raw_body, keys: :atoms)

        # Assert the payload includes required fields
        assert body.stream == false
        assert body.store == false

        # Assert the messages are correctly encoded
        assert Enum.member?(body.messages, %{
                 role: "user",
                 content: "What is the meaning of life?"
               })

        assert Enum.member?(body.messages, %{
                 role: "system",
                 content: "You are a helpful assistant."
               })

        Req.Test.json(conn, %{
          "choices" => [%{"message" => %{"role" => "assistant", "content" => "42"}}],
          "usage" => %{"prompt_tokens" => 5, "total_tokens" => 10}
        })
      end)

      context = %{
        messages: [
          %{role: "system", content: "You are a helpful assistant."},
          %{role: "user", content: "What is the meaning of life?"}
        ]
      }

      result = Weaver.Api.OpenAI.chat(context)

      assert result.message.content == "42"
      assert result.input_tokens == 5
      assert result.total_tokens == 10
    end

    test "malformed / unexpected response raises MatchError" do
      Req.Test.stub(OpenAIMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/openai/v1/chat/completions"

        # Return a response missing required keys (choices, usage)
        Req.Test.json(conn, %{
          "status" => "ok",
          "model" => "gpt-4"
        })
      end)

      context = %{messages: [%{role: "user", content: "Hello!"}]}

      assert_raise MatchError, fn ->
        Weaver.Api.OpenAI.chat(context)
      end
    end
  end
end
