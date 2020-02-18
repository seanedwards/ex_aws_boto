defmodule ExAws.Boto.Shape.Structure do
  @moduledoc false
  defstruct [:name, :module, :required, :members, :documentation, :metadata]
  @enforce_keys [:module, :members]
end

defmodule ExAws.Boto.Shape.List do
  @moduledoc false
  defstruct [:name, :module, :member_name, :member, :documentation, :metadata, min: nil, max: nil]
  @enforce_keys [:module, :member]
end

defmodule ExAws.Boto.Shape.Map do
  @moduledoc false
  defstruct [:name, :module, :key_module, :value_module, :documentation, :metadata]
  @enforce_keys [:module, :member]
end

defmodule ExAws.Boto.Shape.Basic do
  @moduledoc false
  defstruct [:name, :module, :type, :documentation, :def, :metadata]
  @enforce_keys [:module]
end

defmodule ExAws.Boto.Shape do
  @moduledoc false

  @type shape ::
          %ExAws.Boto.Shape.Structure{}
          | %ExAws.Boto.Shape.List{}
          | %ExAws.Boto.Shape.Basic{}

  @callback shape_spec() :: shape()

  require Logger
  alias ExAws.Boto.Util, as: Util

  @spec generate_module(shape()) :: Macro.t()
  def generate_module(
        %ExAws.Boto.Shape.Structure{
          module: module,
          members: members,
          documentation: docs
        } = shape_spec
      )
      when module != nil do
    members_types =
      members
      |> Enum.map(fn {property, {_name, member_mod}} ->
        {
          property,
          quote do
            unquote(member_mod).t()
          end
        }
      end)

    quote do
      defmodule unquote(module) do
        @behaviour ExAws.Boto.Shape
        @moduledoc unquote(docs)
        @type params :: unquote(members_types)
        @type t :: %__MODULE__{unquote_splicing(members_types)}
        defstruct unquote(members_types |> Enum.map(fn {name, _} -> name end))

        @doc false
        @impl ExAws.Boto.Shape
        def shape_spec(), do: unquote(Macro.escape(shape_spec))

        @spec new(params()) :: t()
        def new(nil) do
          %__MODULE__{}
        end

        def new(args) when is_map(args) do
          %__MODULE__{
            unquote_splicing(
              members
              |> Enum.map(fn {property, {name, member_mod}} ->
                quote do
                  {
                    unquote(property),
                    unquote(member_mod).new(
                      Map.get(args, unquote(property)) || Map.get(args, unquote(name))
                    )
                  }
                end
              end)
            )
          }
        end

        def new(args) when is_list(args) do
          args
          |> Enum.into(%{})
          |> new()
        end
      end
    end
  end

  def generate_module(
        %ExAws.Boto.Shape.List{
          module: module,
          member: member_module,
          member_name: member_name,
          documentation: docs
        } = shape_spec
      )
      when module != nil and member_module != nil do
    quote do
      defmodule unquote(module) do
        @behaviour ExAws.Boto.Shape
        @moduledoc unquote(ExAws.Boto.DocParser.doc_to_markdown(docs))
        @type t :: [unquote(member_module).t()]
        @type params :: t()

        @doc false
        @impl ExAws.Boto.Shape
        def shape_spec(), do: unquote(Macro.escape(shape_spec))

        @spec new(params()) :: t()
        def new(nil) do
          []
        end

        def new(list) when is_list(list) do
          list
          |> Enum.map(fn item ->
            unquote(member_module).new(item)
          end)
        end
      end
    end
  end

  def generate_module(
        %ExAws.Boto.Shape.Map{
          module: module,
          key_module: key_module,
          value_module: value_module,
          documentation: docs
        } = shape_spec
      )
      when module != nil do
    quote do
      defmodule unquote(module) do
        @behaviour ExAws.Boto.Shape
        @moduledoc unquote(ExAws.Boto.DocParser.doc_to_markdown(docs))
        @type t :: %{optional(unquote(key_module).t()) => unquote(value_module).t()}
        @type params :: t()

        @doc false
        @impl ExAws.Boto.Shape
        def shape_spec(), do: unquote(Macro.escape(shape_spec))

        @spec new(params()) :: t()
        def new(nil) do
          []
        end

        def new(map) when is_map(map) do
          map
          |> Enum.map(fn {key, value} ->
            {
              unquote(key_module).new(key),
              unquote(value_module).new(value)
            }
          end)
          |> Enum.into(%{})
        end
      end
    end
  end

  def generate_module(
        %ExAws.Boto.Shape.Basic{
          type: shape_type,
          module: module,
          documentation: docs
        } = shape_spec
      )
      when module != nil do
    quote do
      defmodule unquote(module) do
        @behaviour ExAws.Boto.Shape
        @moduledoc unquote(docs)
        @type t :: unquote(ExAws.Boto.Operation.generate_type_spec(shape_spec))
        @type params :: t()

        @doc false
        @impl ExAws.Boto.Shape
        def shape_spec(), do: unquote(Macro.escape(shape_spec))

        @spec new(params()) :: t()
        def new(val) do
          val
        end
      end
    end
  end

  @spec from_service_json(map(), String.t(), map()) :: shape()
  def from_service_json(
        %{"metadata" => %{"serviceId" => service_id} = service_meta},
        name,
        %{"type" => "structure", "members" => members} = op_def
      ) do
    %ExAws.Boto.Shape.Structure{
      name: name,
      module: Util.module_name(service_id, name),
      required:
        op_def
        |> Map.get("required", [])
        |> Enum.map(&Util.key_to_atom/1),
      members:
        members
        |> Enum.map(fn {name, shape} ->
          {Util.key_to_atom(name), {name, Util.module_name(service_id, shape)}}
        end)
        |> Enum.into(%{}),
      documentation:
        op_def
        |> Map.get("documentation")
        |> ExAws.Boto.DocParser.doc_to_markdown(),
      metadata: service_meta
    }
  end

  def from_service_json(
        %{"metadata" => %{"serviceId" => service_id} = service_meta},
        name,
        %{
          "type" => "map",
          "key" => %{"shape" => key_name},
          "value" => %{"shape" => value_name}
        } = op_def
      ) do
    %ExAws.Boto.Shape.Map{
      name: name,
      module: Util.module_name(service_id, name),
      key_module: Util.module_name(service_id, key_name),
      value_module: Util.module_name(service_id, value_name),
      documentation:
        op_def
        |> Map.get("documentation")
        |> ExAws.Boto.DocParser.doc_to_markdown(),
      metadata: service_meta
    }
  end

  def from_service_json(
        %{"metadata" => %{"serviceId" => service_id} = service_meta},
        name,
        %{"type" => "list", "member" => %{"shape" => member_name}} = op_def
      ) do
    %ExAws.Boto.Shape.List{
      name: name,
      module: Util.module_name(service_id, name),
      member_name: member_name,
      member: Util.module_name(service_id, member_name),
      min: Map.get(op_def, "min"),
      max: Map.get(op_def, "max"),
      documentation:
        op_def
        |> Map.get("documentation")
        |> ExAws.Boto.DocParser.doc_to_markdown(),
      metadata: service_meta
    }
  end

  def from_service_json(
        %{"metadata" => %{"serviceId" => service_id} = service_meta},
        name,
        %{"type" => basic} = op_def
      ) do
    %ExAws.Boto.Shape.Basic{
      name: name,
      module: Util.module_name(service_id, name),
      type: basic,
      def: op_def,
      documentation:
        op_def
        |> Map.get("documentation")
        |> ExAws.Boto.DocParser.doc_to_markdown(),
      metadata: service_meta
    }
  end
end
