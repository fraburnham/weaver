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
  end
end
