defmodule Weaver.Api do
  @moduledoc """
  `Weaver.Api` is a behaviour that describes an api `Weaver.LLM` can use
  """

  @type response :: %{
          message: Weaver.message(),
          input_tokens: non_neg_integer(),
          total_tokens: non_neg_integer()
        }

  @callback start_link() :: GenServer.on_start()
  @callback chat(context :: Weaver.LLM.context()) :: response()
end
