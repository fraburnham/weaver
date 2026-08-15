defmodule Weaver.Personas do
  @moduledoc """
  `Weaver.Personas` handles converting from the persona interface to something `Weaver.LLM` can understand
  """

  alias Weaver.Personas

  defstruct base_dir: nil, name: nil

  def system_prompt(%Personas{base_dir: base_dir, name: persona}) do
    File.read!(Path.join([base_dir, persona, "PERSONA.md"]) |> Path.expand())
  end

  def tools_available(%Personas{base_dir: base_dir, name: persona}) do
    File.read!(Path.join([base_dir, persona, "persona.json"]) |> Path.expand())
    |> Jason.decode!(keys: :atoms)
    |> Map.fetch!(:tools)
  end

  def model(%Personas{base_dir: base_dir, name: persona}) do
    File.read!(Path.join([base_dir, persona, "persona.json"]) |> Path.expand())
    |> Jason.decode!(keys: :atoms)
    |> Map.fetch!(:model)
  end

  def context_window(%Personas{base_dir: base_dir, name: persona}) do
    File.read!(Path.join([base_dir, persona, "persona.json"]) |> Path.expand())
    |> Jason.decode!(keys: :atoms)
    |> Map.get(:context_window)
  end
end
