defmodule Weaver.Api do
  @moduledoc """
  `Weaver.Api` is a behaviour that describes an api `Weaver.LLM` can use
  """

  @callback start_link() :: tuple
  @callback chat(context :: map) :: map
end
