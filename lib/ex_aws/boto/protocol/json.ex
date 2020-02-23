defmodule ExAws.Boto.Protocol.Json do
  @behaviour ExAws.Boto.Protocol

  defstruct [
    :operation,
    :op_spec
  ]

  @impl true
  def make_operation(operation) do
  end

  @impl true
  def parse_response(operation, {:ok, %{body: json}}) do
    %ExAws.Boto.Operation{output: op_mod} = operation.__struct__.op_spec()
    case op_mod do
      nil -> {:ok, nil}
      module -> {:ok, Jason.decode!(json) |> module.new()}
    end
  end

  @impl true
  def parse_response(_operation, {:error, {:http_error, _code, %{body: xml}}}) do
    import SweetXml, only: [sigil_x: 2]
    {:error, SweetXml.xpath(xml, ~x"//.")}
  end


  defimpl ExAws.Operation do
  end

end

