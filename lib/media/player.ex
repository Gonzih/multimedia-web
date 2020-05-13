defmodule Media.Cmd do
  require Logger

  @player "mplayer"
  @fifo_file "/tmp/mplayer-elixir-fifofile"

  def play(file_path) do
    if !File.exists?(@fifo_file) do
      {out, 0} = System.cmd("mkfifo", [@fifo_file])
      Logger.debug("mkfifor: #{out}")
    end

    media = System.find_executable(@player)

    Port.open(
      {:spawn_executable, media},
      [
        :binary,
        :stream,
        :exit_status,
        args: [
          "-fs",
          "-slave",
          "-input",
          "file=#{@fifo_file}",
          file_path
        ]
      ]
    )
  end

  def exit(port) do
    case Port.info(port, :os_pid) do
      {:os_pid, pid} -> System.cmd("kill", ["#{pid}"])
      _ -> Logger.debug "Player not running"
    end


    if File.exists?(@fifo_file) do
      File.rm!(@fifo_file)
    end
  end

  def command(_, cmd) do
    File.write!(@fifo_file, "#{cmd}\n", [:append, :sync])
  end
end

defmodule Media.Player do
  require Logger
  use GenServer
  alias Phoenix.PubSub
  alias Media.Cmd

  @in_topic "media-incoming"
  @out_topic "media-outgoing"

  # CLIENT
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{
      current_file: nil,
      port: nil,
      path: nil,
      queue: [],
    }, name: __MODULE__)
  end

  def current_file do
    GenServer.call(__MODULE__, {:current_file})
  end

  def queue do
    GenServer.call(__MODULE__, {:queue})
  end

  def play(fname, path) do
    GenServer.cast(__MODULE__, {:play, fname, path})
  end

  def dequeue(path) do
    GenServer.cast(__MODULE__, {:dequeue, path})
  end

  def dequeue_all() do
    GenServer.cast(__MODULE__, {:dequeue, :all})
  end

  def stop do
    GenServer.cast(__MODULE__, {:stop})
  end

  def command(cmd) do
    GenServer.cast(__MODULE__, {:command, cmd})
  end

  def notify_state_change do
    PubSub.broadcast(
      Media.PubSub,
      @out_topic,
      %{topic: @out_topic, payload: :state_changed}
    )
  end

  @impl true
  def init(state) do
    PubSub.subscribe(Media.PubSub, @in_topic)

    {:ok, state}
  end

  @impl true
  def handle_call({:current_file}, _from, %{current_file: fname} = state), do:
    {:reply, fname, state}

  @impl true
  def handle_call({:queue}, _from, %{queue: queue} = state), do:
    {:reply, queue, state}


  @impl true
  def handle_cast({:play, fname, path}, %{queue: _, current_file: nil} = state) do
    notify_state_change()
    port = Cmd.play(path)

    {:noreply, %{state | current_file: fname, path: path, port: port}}
  end

  @impl true
  def handle_cast({:play, fname, path}, %{queue: queue, current_file: _} = state) do
    notify_state_change()

    {:noreply, %{state | queue: queue ++ [{fname, path}]}}
  end

  @impl true
  def handle_cast({:stop}, %{port: port} = state) do
    Cmd.exit(port)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:dequeue, :all}, state) do
    notify_state_change()
    {:noreply, %{state | queue: []}}
  end

  @impl true
  def handle_cast({:dequeue, target_path}, %{queue: queue} = state) do
    notify_state_change()
    q = Enum.reject(queue, fn {_, path} -> path == target_path end)

    {:noreply, %{state | queue: q}}
  end

  @impl true
  def handle_cast({:command, cmd}, %{port: port} = state) do
    Cmd.command(port, cmd)

    {:noreply, state}
  end

  @impl true
  def handle_info({_, {:exit_status, _}}, %{queue: []} = state) do
    notify_state_change()
    {:noreply, %{state | current_file: nil, port: nil, path: nil, queue: []}}
  end

  @impl true
  def handle_info({_, {:exit_status, _}}, %{queue: [{fname, path} | queue]} = state) do
    notify_state_change()
    Media.Player.play(fname, path)
    {:noreply, %{state | current_file: nil, port: nil, path: nil, queue: queue}}
  end

  @impl true
  def handle_info({_, {:data, data}}, state) do
    # Logger.debug("mplayer: #{data}")
    {:noreply, state}
  end
end
