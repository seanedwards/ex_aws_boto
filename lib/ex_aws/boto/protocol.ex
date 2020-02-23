defmodule ExAws.Boto.Protocol do
  @type http_reply ::
    {:ok, %{body: String.t()}} |
    {:error, term()}
  
  @type boto_reply ::
    {:ok, struct() | nil} |
    {:error, term()}

  @callback perform(struct()) :: boto_reply()

  defstruct operation: nil

  defimpl ExAws.Operation do
    def perform(%ExAws.Boto.Protocol{operation: operation}, config) do
      operation.__struct__.op_spec().protocol.perform(operation, config)
    end


    def stream!(operation, _) do
      operation.__struct__.stream(operation)
    end
  end
end
