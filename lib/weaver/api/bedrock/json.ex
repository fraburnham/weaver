defmodule Weaver.Api.Bedrock.Json do
  @behaviour ExAws.JSON.Codec

  @moduledoc false

  def encode!(%{} = map) do
    Jason.encode!(map)
  end

  def encode(map) do
    try do
      {:ok, encode!(map)}
    rescue
      ArgumentError -> {:error, :badarg}
    end
  end

  def decode!(string) do
    Jason.decode!(string, keys: :atoms)
  end

  def decode(string) do
    try do
      {:ok, decode!(string)}
    rescue
      ArgumentError -> {:error, :badarg}
    end
  end
end
