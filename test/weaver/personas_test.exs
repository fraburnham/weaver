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
end
