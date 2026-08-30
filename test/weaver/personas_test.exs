defmodule Weaver.PersonasTest do
  use ExUnit.Case

  alias Weaver.Personas

  setup do
    # Create a unique temporary directory for this test session
    base_dir = Path.join(System.tmp_dir!(), "weaver_personas_test_#{:rand.uniform(10000)}")
    File.mkdir_p!(base_dir)

    # Create a test persona directory
    persona_dir = Path.join(base_dir, "test_persona")
    File.mkdir_p!(persona_dir)

    on_exit(fn ->
      File.rm_rf(base_dir)
    end)

    %{base_dir: base_dir, persona_dir: persona_dir}
  end

  describe "system_prompt/1" do
    test "returns the content of PERSONA.md", context do
      persona_path = context[:persona_dir]
      File.write!(Path.join(persona_path, "PERSONA.md"), "You are a helpful assistant.")

      persona = %Personas{base_dir: context[:base_dir], name: "test_persona"}
      assert Personas.system_prompt(persona) == "You are a helpful assistant."
    end

    test "preserves whitespace and newlines", context do
      persona_path = context[:persona_dir]
      prompt = """
      System Prompt
      Line 2
      \tLine 3
      """
      File.write!(Path.join(persona_path, "PERSONA.md"), prompt)

      persona = %Personas{base_dir: context[:base_dir], name: "test_persona"}
      assert Personas.system_prompt(persona) == prompt
    end

    test "returns empty string for empty PERSONA.md", context do
      persona_path = context[:persona_dir]
      File.write!(Path.join(persona_path, "PERSONA.md"), "")

      persona = %Personas{base_dir: context[:base_dir], name: "test_persona"}
      assert Personas.system_prompt(persona) == ""
    end

    test "raises File.Error when PERSONA.md is missing", context do
      persona = %Personas{base_dir: context[:base_dir], name: "test_persona"}
      assert_raise File.Error, fn ->
        Personas.system_prompt(persona)
      end
    end
  end

  describe "tools_available/1" do
    test "returns the list of tools from persona.json", context do
      persona_path = context[:persona_dir]
      json = ~s|{"model": "gpt-4", "api": "OpenAI", "tools": ["code_interpreter", "dalle"]}|
      File.write!(Path.join(persona_path, "persona.json"), json)

      persona = %Personas{base_dir: context[:base_dir], name: "test_persona"}
      assert Personas.tools_available(persona) == ["code_interpreter", "dalle"]
    end

    test "raises KeyError when tools key is missing", context do
      persona_path = context[:persona_dir]
      json = ~s|{"model": "gpt-4", "api": "OpenAI"}|
      File.write!(Path.join(persona_path, "persona.json"), json)

      persona = %Personas{base_dir: context[:base_dir], name: "test_persona"}
      assert_raise KeyError, fn ->
        Personas.tools_available(persona)
      end
    end

    test "raises Jason.DecodeError when JSON is malformed", context do
      persona_path = context[:persona_dir]
      File.write!(Path.join(persona_path, "persona.json"), "{invalid json")

      persona = %Personas{base_dir: context[:base_dir], name: "test_persona"}
      assert_raise Jason.DecodeError, fn ->
        Personas.tools_available(persona)
      end
    end

    test "raises File.Error when persona.json is missing", context do
      persona = %Personas{base_dir: context[:base_dir], name: "test_persona"}
      assert_raise File.Error, fn ->
        Personas.tools_available(persona)
      end
    end

    test "returns empty list when tools is empty", context do
      persona_path = context[:persona_dir]
      json = ~s|{"model": "gpt-4", "api": "OpenAI", "tools": []}|
      File.write!(Path.join(persona_path, "persona.json"), json)

      persona = %Personas{base_dir: context[:base_dir], name: "test_persona"}
      assert Personas.tools_available(persona) == []
    end
  end

  describe "model/1" do
    test "returns a tuple {model_string, Module} for valid config", context do
      persona_path = context[:persona_dir]
      json = ~s|{"model": "gpt-4", "api": "OpenAI", "tools": []}|
      File.write!(Path.join(persona_path, "persona.json"), json)

      persona = %Personas{base_dir: context[:base_dir], name: "test_persona"}
      {model, api_module} = Personas.model(persona)

      assert model == "gpt-4"
      assert api_module == Module.concat(["OpenAI"])
    end

    test "raises MatchError when model key is missing", context do
      persona_path = context[:persona_dir]
      json = ~s|{"api": "OpenAI", "tools": []}|
      File.write!(Path.join(persona_path, "persona.json"), json)

      persona = %Personas{base_dir: context[:base_dir], name: "test_persona"}
      assert_raise MatchError, fn ->
        Personas.model(persona)
      end
    end

    test "raises MatchError when api key is missing", context do
      persona_path = context[:persona_dir]
      json = ~s|{"model": "gpt-4", "tools": []}|
      File.write!(Path.join(persona_path, "persona.json"), json)

      persona = %Personas{base_dir: context[:base_dir], name: "test_persona"}
      assert_raise MatchError, fn ->
        Personas.model(persona)
      end
    end

    test "constructs correct module from api string", context do
      persona_path = context[:persona_dir]
      json = ~s|{"model": "llama3", "api": "Ollama", "tools": []}|
      File.write!(Path.join(persona_path, "persona.json"), json)

      persona = %Personas{base_dir: context[:base_dir], name: "test_persona"}
      {model, api_module} = Personas.model(persona)

      assert model == "llama3"
      assert api_module == Module.concat(["Ollama"])
    end

    test "raises File.Error when persona.json is missing", context do
      persona = %Personas{base_dir: context[:base_dir], name: "test_persona"}
      assert_raise File.Error, fn ->
        Personas.model(persona)
      end
    end

    test "raises Jason.DecodeError when JSON is malformed", context do
      persona_path = context[:persona_dir]
      File.write!(Path.join(persona_path, "persona.json"), "{invalid json")

      persona = %Personas{base_dir: context[:base_dir], name: "test_persona"}
      assert_raise Jason.DecodeError, fn ->
        Personas.model(persona)
      end
    end
  end

  describe "context_window/1" do
    test "returns the integer value specified in context_window", context do
      persona_path = context[:persona_dir]
      json = ~s|{"model": "gpt-4", "api": "OpenAI", "tools": [], "context_window": 8192}|
      File.write!(Path.join(persona_path, "persona.json"), json)

      persona = %Personas{base_dir: context[:base_dir], name: "test_persona"}
      assert Personas.context_window(persona) == 8192
    end

    test "returns nil when context_window key is missing", context do
      persona_path = context[:persona_dir]
      json = ~s|{"model": "gpt-4", "api": "OpenAI", "tools": []}|
      File.write!(Path.join(persona_path, "persona.json"), json)

      persona = %Personas{base_dir: context[:base_dir], name: "test_persona"}
      assert Personas.context_window(persona) == nil
    end

    test "raises Jason.DecodeError when JSON is malformed", context do
      persona_path = context[:persona_dir]
      File.write!(Path.join(persona_path, "persona.json"), "{invalid json")

      persona = %Personas{base_dir: context[:base_dir], name: "test_persona"}
      assert_raise Jason.DecodeError, fn ->
        Personas.context_window(persona)
      end
    end

    test "raises File.Error when persona.json is missing", context do
      persona = %Personas{base_dir: context[:base_dir], name: "test_persona"}
      assert_raise File.Error, fn ->
        Personas.context_window(persona)
      end
    end
  end
end