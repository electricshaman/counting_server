defmodule CountingServer.Mixfile do
  use Mix.Project

  def project do
    [app: :counting_server,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger],
     mod: {CountingServer.Application, []}]
  end

  defp deps do
    [{:ranch, "~> 1.3"}]
  end
end
