defmodule CountingServer.Protocol do
  require Logger

  @behaviour :ranch_protocol
  @default_interval 1000

  def start_link(ref, socket, transport, opts) do
    :proc_lib.start_link(__MODULE__, :init, [ref, socket, transport, opts])
  end

  def init(ref, socket, transport, opts) do
    :ok = :proc_lib.init_ack({:ok, self()})

    # State initialization here
    {:ok, peer} = :ranch_tcp.peername(socket)
    Logger.debug "Connection established. #{inspect self()}, #{format_peer(peer)}"

    interval = Keyword.get(opts, :interval, @default_interval)
    Process.send_after(self(), :send_count, interval)

    :ok = :ranch.accept_ack(ref)
    transport.setopts(socket, [active: :once])

    :gen_server.enter_loop(__MODULE__, [], %{
      counter: 0,
      interval: interval,
      peer: peer,
      ref: ref,
      socket: socket,
      transport: transport})
  end

  @b8  trunc(:math.pow(2, 8))
  @b16 trunc(:math.pow(2, 16))
  @b32 trunc(:math.pow(2, 32))
  @b64 trunc(:math.pow(2, 64))

  @doc """
  Send the next number to a connected peer
  """
  def handle_info(:send_count, state) do
    next = state.counter + 1

    bin = cond do
      next < @b8 ->  <<next :: 8>>
      next < @b16 -> <<next :: 16>>
      next < @b32 -> <<next :: 32>>
      next < @b64 -> <<next :: 64>>
      true ->        <<0>> # Not supported
    end

    Logger.debug "Sending #{next} to #{format_peer(state.peer)}"
    state.transport.send(state.socket, bin)
    Process.send_after(self(), :send_count, state.interval)

    {:noreply, %{state | counter: next}}
  end

  @doc """
  Called when command to change the interval is received on the socket.
  """
  def handle_info({:tcp, socket, <<0xFF, interval :: 16>>}, state) do
    state.transport.setopts(socket, [active: :once])
    Logger.debug "Changing interval to #{interval}"
    {:noreply, %{state | interval: interval}}
  end

  @doc """
  Called when unknown data is received on the socket.
  """
  def handle_info({:tcp, socket, bin}, state) do
    state.transport.setopts(socket, [active: :once])
    Logger.debug "Received #{inspect bin}"
    {:noreply, state}
  end

  @doc """
  Called when the TCP connection is closed unexpectedly.
  """
  def handle_info({:tcp_closed, _socket}, state) do
    {:stop, :normal, state}
  end

  @doc """
  Called when an unrecognized message is received by the process.
  """
  def handle_info(other, state) do
    Logger.debug("Unrecognized message received: #{inspect other}")
    {:noreply, state}
  end

  @doc """
  Called sometimes when the connection process is terminated
  """
  def terminate(reason, state) do
    Logger.debug "Process terminated: #{inspect self()}, reason: #{inspect reason}, state: #{inspect state}"
    :shutdown
  end

  defp format_peer({{o1, o2, o3, o4}, port}) do
    "#{o1}.#{o2}.#{o3}.#{o4}:#{port}"
  end
end
