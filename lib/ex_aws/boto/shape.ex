defmodule ExAws.Boto.Shape.Structure do
  @moduledoc false
  defstruct [:name, :module, :required, :members, :documentation, :metadata]
end

defmodule ExAws.Boto.Shape.List do
  @moduledoc false
  defstruct [:name, :module, :member_name, :member, :documentation, :metadata, min: nil, max: nil]
end

defmodule ExAws.Boto.Shape.Map do
  @moduledoc false
  defstruct [:name, :module, :key_module, :value_module, :documentation, :metadata]
end

defmodule ExAws.Boto.Shape.Basic do
  @moduledoc false
  defstruct [:name, :module, :type, :documentation, :def, :metadata]
end

defmodule ExAws.Boto.Shape do
  @moduledoc false

  @type t ::
          %ExAws.Boto.Shape.Structure{}
          | %ExAws.Boto.Shape.List{}
          | %ExAws.Boto.Shape.Map{}
          | %ExAws.Boto.Shape.Basic{}

  @callback shape_spec() :: t()
  @callback new(term()) :: term()
  @callback destruct(term()) :: term()

  alias ExAws.Boto.Util, as: Util

  def from_service_json(%{"metadata" => %{"serviceId" => service_id}} = service_json, name) do
    module = Util.module_name(service_id, name)
    if function_exported?(module, :shape_spec, 0) do
      module.shape_spec()
    else
      spec = generate_shape_spec(service_json, name)

      spec
      |> generate_module()
      |> Code.compile_quoted("Shape #{inspect(module)}")

      spec
    end
  end

  def generate_shape_spec(%{"shapes" => shapes} = service_json, name) do
    shape_def =
      shapes
      |> Map.get(name)
    generate_shape_spec(service_json, name, shape_def)
  end

  @spec generate_shape_spec(map(), String.t()) :: t()
  def generate_shape_spec(
        %{"metadata" => %{"serviceId" => service_id} = service_meta},
        name,
        %{"members" => members} = shape_def
      ) do
    %ExAws.Boto.Shape.Structure{
      name: name,
      module: Util.module_name(service_id, name),
      required:
        shape_def
        |> Map.get("required", [])
        |> Enum.map(&Util.key_to_atom/1),
      members:
        members
        |> Enum.map(fn {name, shape} ->
          {Util.key_to_atom(name), {name, Util.module_name(service_id, shape)}}
        end)
        |> Enum.into(%{}),
      documentation:
        shape_def
        |> Map.get("documentation")
        |> ExAws.Boto.DocParser.doc_to_markdown(),
      metadata: service_meta
    }
  end

  def generate_shape_spec(
        %{"metadata" => %{"serviceId" => service_id} = service_meta},
        name,
        %{
          "type" => "map",
          "key" => %{"shape" => key_name},
          "value" => %{"shape" => value_name}
        } = shape_def
      ) do
    %ExAws.Boto.Shape.Map{
      name: name,
      module: Util.module_name(service_id, name),
      key_module: Util.module_name(service_id, key_name),
      value_module: Util.module_name(service_id, value_name),
      documentation:
        shape_def
        |> Map.get("documentation")
        |> ExAws.Boto.DocParser.doc_to_markdown(),
      metadata: service_meta
    }
  end

  def generate_shape_spec(
        %{"metadata" => %{"serviceId" => service_id} = service_meta},
        name,
        %{"type" => "list", "member" => %{"shape" => member_name}} = shape_def
      ) do
    %ExAws.Boto.Shape.List{
      name: name,
      module: Util.module_name(service_id, name),
      member_name: member_name,
      member: Util.module_name(service_id, member_name),
      min: Map.get(shape_def, "min"),
      max: Map.get(shape_def, "max"),
      documentation:
        shape_def
        |> Map.get("documentation")
        |> ExAws.Boto.DocParser.doc_to_markdown(),
      metadata: service_meta
    }
  end

  def generate_shape_spec(
        %{"metadata" => %{"serviceId" => service_id} = service_meta},
        name,
        %{"type" => basic} = shape_def
      ) do
    %ExAws.Boto.Shape.Basic{
      name: name,
      module: Util.module_name(service_id, name),
      type: basic,
      def: shape_def,
      documentation:
        shape_def
        |> Map.get("documentation")
        |> ExAws.Boto.DocParser.doc_to_markdown(),
      metadata: service_meta
    }
  end
  @spec generate_module(t()) :: Macro.t()
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
        @impl ExAws.Boto.Shape
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

        @doc false
        @spec destruct(t()) :: map()
        @impl ExAws.Boto.Shape
        def destruct(%__MODULE__{} = struct) do
          %{
            unquote_splicing(
              members
              |> Enum.map(fn {property, {name, member_mod}} ->
                quote do
                  {unquote(name), unquote(member_mod).destruct(struct.unquote(property))}
                end
                end)
            )
          }
        end
      end
    end
  end

  def generate_module(
        %ExAws.Boto.Shape.List{
          module: module,
          member: member_module,
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
        @impl ExAws.Boto.Shape
        def new(nil) do
          []
        end

        def new(list) when is_list(list) do
          list
          |> Enum.map(fn item ->
            unquote(member_module).new(item)
          end)
        end

        @spec destruct(t()) :: [...]
        @impl ExAws.Boto.Shape
        def destruct(list) when is_list(list) do
          list |> Enum.map(&unquote(member_module).destruct/1)
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
        @impl ExAws.Boto.Shape
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

        @spec destruct(t()) :: map()
        @impl ExAws.Boto.Shape
        def destruct(map) when is_map(map) do
          map
          |> Enum.map(fn {key, value} ->
            {
              unquote(key_module).destruct(key),
              unquote(value_module).destruct(value)
            }
          end)
          |> Enum.into(%{})
        end
      end
    end
  end

  def generate_module(
        %ExAws.Boto.Shape.Basic{
          module: module
        } = shape_spec
      )
      when module != nil do
    quote do
      defmodule unquote(module) do
        @behaviour ExAws.Boto.Shape
        @moduledoc unquote(generate_docs(shape_spec))
        @type t :: unquote(generate_type_spec(shape_spec))
        @type params :: t()

        @doc false
        @impl ExAws.Boto.Shape
        def shape_spec(), do: unquote(Macro.escape(shape_spec))

        @spec new(params()) :: t()
        @impl ExAws.Boto.Shape
        def new(val) do
          val
        end

        @spec destruct(t()) :: t()
        @impl ExAws.Boto.Shape
        def destruct(val) do
          val
        end
      end
    end
  end

  def generate_docs(%ExAws.Boto.Shape.Structure{documentation: docs} = _shape_spec) do
    quote do
      unquote(ExAws.Boto.DocParser.doc_to_markdown(docs))
    end
  end

  def generate_docs(_) do
    false
  end

  def generate_type_spec(shape_spec) do
    # In actually implementing this function, we need to be careful about recursive data types.
    # A mapset is used to track which structs we've actually generated, so if there's a
    # cycle in the type hierarchy, we can just reference the `.t()` typespec and move on.
    do_generate_type_spec(shape_spec, MapSet.new())
  end

  defp do_generate_type_spec(nil, _in_progress) do
    quote do: nil
  end

  defp do_generate_type_spec(atom, in_progress) when is_atom(atom) do
    do_generate_type_spec(atom.shape_spec(), in_progress)
  end

  defp do_generate_type_spec(%ExAws.Boto.Shape.Structure{
        module: module,
        members: members,
        required: required
      }, in_progress) do
    if MapSet.member?(in_progress, module) do
      quote do
        unquote(module).t()
      end
    else
      in_progress = MapSet.put(in_progress, module)
      quote do
        %unquote(module){
          unquote_splicing(
            members
            |> Enum.map(fn {attr, {_name, module}} ->
              cond do
                Enum.member?(required, attr) ->
                  {attr, do_generate_type_spec(module.shape_spec(), in_progress)}

                true ->
                  {attr,
                   quote do
                     nil | unquote(do_generate_type_spec(module.shape_spec(), in_progress))
                 end}
              end
            end)
          )
        }
      end
    end
  end

  defp do_generate_type_spec(%ExAws.Boto.Shape.List{
        member: member
      }, in_progress) do
    quote do
      [unquote(do_generate_type_spec(member.shape_spec(), in_progress))]
    end
  end

  defp do_generate_type_spec(%ExAws.Boto.Shape.Map{
        key_module: key_module,
        value_module: value_module
      }, in_progress) do
    quote do
      %{
        optional(unquote(do_generate_type_spec(key_module, in_progress))) =>
          unquote(do_generate_type_spec(value_module, in_progress))
      }
    end
  end

  defp do_generate_type_spec(%ExAws.Boto.Shape.Basic{type: "string"}, _in_progress) do
    quote do: String.t()
  end

  defp do_generate_type_spec(%ExAws.Boto.Shape.Basic{type: "timestamp"}, _in_progress) do
    quote do: String.t()
  end

  defp do_generate_type_spec(%ExAws.Boto.Shape.Basic{type: "integer"}, _in_progress) do
    quote do: integer()
  end

  defp do_generate_type_spec(%ExAws.Boto.Shape.Basic{type: "long"}, _in_progress) do
    quote do: integer()
  end

  defp do_generate_type_spec(%ExAws.Boto.Shape.Basic{type: "boolean"}, _in_progress) do
    quote do: true | false
  end

  defp do_generate_type_spec(%ExAws.Boto.Shape.Basic{type: "blob"}, _in_progress) do
    quote do: binary()
  end

  defp do_generate_type_spec(_, _) do
    quote do: any()
  end


end
