# ExAwsBoto

Generate ExAws clients from Botocore JSON specs

For example:

```elixir
iex> ExAws.Boto.load(iam: "2010-05-08")
:ok

iex> ExAws.IAM.Api.list_users |> ExAws.IAM.Client.request!()
[
  # possibly a lot of users...
]
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ex_aws_boto` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_aws_boto, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ex_aws_boto](https://hexdocs.pm/ex_aws_boto).

