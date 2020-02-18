use Mix.Config

config :mojito,
  timeout: 2500,
  pool_opts: [
    size: 10
  ]

config :ex_aws,
  http_client: ExAws.Mojito
