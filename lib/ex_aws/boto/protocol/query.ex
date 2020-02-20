defmodule ExAws.Boto.Protocol.Query do
  require Logger
  import SweetXml, only: [sigil_x: 2]

  @behaviour ExAws.Boto.Protocol

  @doc """
  Converts an `ExAws.Boto.Operation`, which describes an API method invocation in terms of `ExAws.Boto`
  into an `ExAws.Operation.Query`, which describes an HTTP request. This method is also responsible for
  converting the input object into something that an AWS query strings based API can understand.
  """
  @impl true
  def make_operation(operation) do
    %ExAws.Boto.Operation{
      name: op_name_str,
      input: input_mod,
      http: %{
        "requestUri" => http_path
      },
      metadata: %{
        "protocol" => "query",
        "endpointPrefix" => endpoint_prefix,
        "apiVersion" => version
      }
    } = operation.__struct__.op_spec()

    params =
      case input_mod do
        nil ->
          %{}

        mod ->
          to_aws(mod.shape_spec(), operation.input)
      end
      |> Enum.flat_map(fn
        {_key, nil} ->
          []

        {key, val} when is_list(val) ->
          ExAws.Utils.format(val, type: :xml, prefix: "#{key}.member")

        {key, val} ->
          ExAws.Utils.format(val, type: :xml, prefix: key)
      end)

    %ExAws.Operation.Query{
      path: http_path,
      action: op_name_str,
      service: String.to_atom(endpoint_prefix),
      params: [
        {"Action", op_name_str},
        {"Version", version}
        | params
      ]
    }
  end

  @doc """
  Parses an ExAWS response into an `ExAws.Boto` object.
  """
  @impl true
  def parse_response(operation, {:ok, %{body: xml}}) do
    %ExAws.Boto.Operation{
      output: output_mod,
      output_wrapper: wrapper
    } = operation.__struct__.op_spec()

    result =
      case wrapper do
        nil -> SweetXml.xpath(xml, ~x"./"e)
        w -> SweetXml.xpath(xml, ~x"./#{w}")
      end

    case output_mod do
      nil -> {:ok, nil}
      mod -> {:ok, parse(mod.shape_spec(), result)}
    end
  end

  @doc """
  Given a `ExAws.Boto.Shape` and a fragment of XML, produce a domain object representing that XML
  """
  @spec parse(ExAws.Boto.Shape.t(), term()) :: struct()
  def parse(shape_spec, xml)

  def parse(%ExAws.Boto.Shape.Structure{module: module}, nil) do
    Kernel.struct(module, [])
  end

  def parse(%ExAws.Boto.Shape.Structure{module: module, members: members}, xml) do
    result =
      members
      |> Enum.map(fn {attr, {member_name, member_mod}} ->
        attr_xml = SweetXml.xpath(xml, ~x"./#{member_name}"e)

        {
          attr,
          parse(member_mod.shape_spec(), attr_xml)
        }
      end)

    Kernel.struct(module, result)
  end

  def parse(%ExAws.Boto.Shape.List{}, nil), do: []

  def parse(%ExAws.Boto.Shape.List{member: member_module}, xml) do
    xml
    |> SweetXml.xpath(~x"./member"el)
    |> Enum.map(&parse(member_module.shape_spec(), &1))
  end

  def parse(%ExAws.Boto.Shape.Map{}, nil), do: %{}

  def parse(%ExAws.Boto.Shape.Map{key_module: key_module, value_module: value_module}, xml) do
    xml
    |> SweetXml.xpath(~x".")
    |> Enum.map(fn {k, v} ->
      {
        parse(key_module.shape_spec(), k),
        parse(value_module.shape_spec(), v)
      }
    end)
    |> Enum.into(%{})
  end

  def parse(_, nil), do: nil

  def parse(%ExAws.Boto.Shape.Basic{type: t}, xml) when t in ["integer", "long"] do
    xml
    |> SweetXml.xpath(~x"./text()"s)
    |> String.to_integer()
  end

  def parse(%ExAws.Boto.Shape.Basic{type: "boolean"}, xml) do
    SweetXml.xpath(xml, ~x"./text()"s) == "true"
  end

  def parse(%ExAws.Boto.Shape.Basic{type: "timestamp"}, xml) do
    {:ok, timestamp, 0} =
      xml
      |> SweetXml.xpath(~x"./text()"s)
      |> DateTime.from_iso8601()

    timestamp
  end

  def parse(%ExAws.Boto.Shape.Basic{type: "string"}, xml) do
    xml |> SweetXml.xpath(~x"./text()"s)
  end

  defp to_aws(%ExAws.Boto.Shape.Structure{module: module, members: members}, %module{} = req) do
    members
    |> Enum.map(fn {property, {name, member_mod}} ->
      {
        name,
        case Map.get(req, property) do
          nil -> nil
          value -> to_aws(member_mod.shape_spec(), value)
        end
      }
    end)
    |> Enum.into(%{})
  end

  defp to_aws(%ExAws.Boto.Shape.List{member_name: m_name, member: m_mod}, list)
       when is_list(list) do
    %{
      m_name => list |> Enum.map(&to_aws(m_mod.shape_spec(), &1))
    }
  end

  defp to_aws(%ExAws.Boto.Shape.Basic{}, val) do
    val
  end
end
