defmodule ExAws.Boto.Protocol do
  @type http_reply ::
    {:ok, %{body: String.t()}} |
    {:error, term()}
  
  @type boto_reply ::
    {:ok, struct() | nil} |
    {:error, term()}

  @callback make_operation(operation :: struct()) :: struct()
  @callback parse_response(operation :: struct(), http_reply) :: boto_reply
end
