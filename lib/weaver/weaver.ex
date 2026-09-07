defmodule Weaver do
  @type tool_call :: %{
          function: %{
            optional(:description) => String.t(),
            optional(:arguments) => map(),
            name: String.t()
          }
        }

  @type user_message :: %{
          optional(:resume) => boolean(),
          role: String.t(),
          content: String.t()
        }

  @type tool_message :: %{
          optional(:resume) => boolean(),
          id: integer(),
          role: String.t(),
          content: String.t()
        }

  @type assistant_message :: %{
          optional(:resume) => boolean(),
          optional(:content) => String.t(),
          optional(:thinking) => String.t(),
          optional(:tool_calls) => [tool_call()],
          role: String.t()
        }

  @type message :: user_message() | tool_message() | assistant_message()

  @type command ::
          :clear | :compact | {:resume, command()} | :resume_end | {:terminal_tool_call, any()}

  @type metric :: %{
          total_tokens: non_neg_integer(),
          input_tokens: non_neg_integer()
        }
end
