defmodule Weaver.Api.OllamaTest do
  use ExUnit.Case, async: true

  describe "chat/1" do
    test "successful standard chat response" do
      Req.Test.stub(:ollama_api, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/chat"

        body = Jason.decode!(Req.Test.raw_body(conn), keys: :atoms)
        assert body.stream == false
        assert Enum.member?(body.messages, %{role: "user", content: "Hello!"})

        Req.Test.json(conn, %{
          "message" => %{"role" => "assistant", "content" => "Hi there!"},
          "prompt_eval_count" => 5,
          "eval_count" => 10
        })
      end)

      context = %{messages: [%{role: "user", content: "Hello!"}]}
      result = Weaver.Api.Ollama.chat(context)

      assert result.message == %{role: "assistant", content: "Hi there!"}
      assert result.input_tokens == 5
      assert result.total_tokens == 15
    end

    test "tool call response handling" do
      Req.Test.stub(:ollama_api, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/chat"

        body = Jason.decode!(Req.Test.raw_body(conn), keys: :atoms)
        assert body.stream == false

        Req.Test.json(conn, %{
          "message" => %{
            "role" => "assistant",
            "content" => "",
            "tool_calls" => [
              %{
                "function" => %{
                  "index" => 0,
                  "name" => "get_weather",
                  "arguments" => %{"location" => "Boston"},
                  "id" => "call_abc123"
                }
              }
            ]
          },
          "prompt_eval_count" => 50,
          "eval_count" => 30
        })
      end)

      context = %{messages: [%{role: "user", content: "What's the weather in Boston?"}]}
      result = Weaver.Api.Ollama.chat(context)

      assert result.message.role == "assistant"
      assert result.message.tool_calls != nil
      tool_call = Enum.at(result.message.tool_calls, 0)
      assert tool_call.function.name == "get_weather"
      assert tool_call.function.arguments.location == "Boston"
      assert result.input_tokens == 50
      assert result.total_tokens == 80
    end
    test "token accounting verification" do
      Req.Test.stub(:ollama_api, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/chat"

        Req.Test.json(conn, %{
          "message" => %{"role" => "assistant", "content" => "Test response"},
          "prompt_eval_count" => 10,
          "eval_count" => 20
        })
      end)

      context = %{messages: [%{role: "user", content: "Test prompt"}]}
      result = Weaver.Api.Ollama.chat(context)

      assert result.input_tokens == 10
      assert result.total_tokens == 30
    end
  end
end