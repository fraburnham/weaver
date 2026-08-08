defmodule Weaver.Api do
  @moduledoc """
  `Weaver.Api` describes a api that `Weaver.LLM` can use
  """

  @callback start_link() :: tuple
  @callback chat(context :: map) :: map
end
