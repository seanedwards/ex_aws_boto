# ExAws.Boto

Generate ExAws clients from Botocore JSON specs.

Work in progress, definitely has bugs. Try it out, but wait for `1.x` before using it in production.

For example:

```elixir
iex> ExAws.Boto.load(iam: "2010-05-08")
:ok

iex> ExAws.IAM.Api.list_users
...> |> ExAws.IAM.Client.request!()
%ExAws.IAM.ListUsersResponse{
  users: [
    # between zero and several users...
  ]
}
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ex_aws_boto` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_aws_boto, "~> 0.1.0"},
    {:botocore, github: "boto/botocore", compile: false, app: false, runtime: false}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ex_aws_boto](https://hexdocs.pm/ex_aws_boto).

