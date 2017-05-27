defmodule CountingServer.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    port = Application.get_env(:counting_server, :port)
    interval = Application.get_env(:counting_server, :interval_ms)

    children = [
      :ranch.child_spec(:tcp_counting, 100, :ranch_tcp, [{:port, port}], CountingServer.Protocol, [interval: interval])
    ]

    opts = [strategy: :one_for_one, name: CountingServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
