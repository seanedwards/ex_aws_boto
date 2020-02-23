defmodule ExAws.Boto.Request do
  defstruct operation: nil
end

defimpl ExAws.Operation, for: ExAws.Boto.Request do
  def perform(%ExAws.Boto.Request{operation: operation}, config) do
    operation.__struct__.op_spec().protocol.perform(operation, config)
  end


  def stream!(_, _) do
  end
end

