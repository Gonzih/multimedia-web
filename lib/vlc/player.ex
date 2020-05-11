defmodule Vlc.Cmd do
  def play(file_path) do
    vlc = System.find_executable("vlc")

    Port.open({:spawn_executable, vlc}, [:binary, :stream, :exit_status, args: ["--fullscreen", file_path]])
  end

  def exit(port) do
    case Port.info(port, :os_pid) do
      {:os_pid, pid} -> System.cmd("kill", ["#{pid}"])
      _ -> IO.puts "Already exited"
    end
  end
end

defmodule Vlc.Player do
  use GenServer
  alias Phoenix.PubSub
  alias Vlc.Cmd

  @in_topic "vlc-incoming"
  @out_topic "vlc-outgoing"

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

  def stop do
    GenServer.cast(__MODULE__, {:stop})
  end

  def notify_state_change do
    PubSub.broadcast(
      Vlc.PubSub,
      @out_topic,
      %{topic: @out_topic, payload: :state_changed}
    )
  end

  @impl true
  def init(state) do
    PubSub.subscribe(Vlc.PubSub, @in_topic)

    {:ok, state}
  end

  @impl true
  def handle_call({:current_file}, _from, %{current_file: fname} = state), do:
    {:reply, fname, state}

  @impl true
  def handle_call({:queue}, _from, %{queue: queue} = state), do:
    {:reply, queue, state}


  @impl true
  def handle_cast({:play, fname, path}, %{queue: queue, current_file: nil} = state) do
    notify_state_change()
    port = Cmd.play(path)

    {:noreply, Map.merge(state, %{current_file: fname, path: path, port: port})}
  end

  @impl true
  def handle_cast({:play, fname, path}, %{queue: queue, current_file: current_file} = state) do
    notify_state_change()

    {:noreply, Map.merge(state, %{queue: queue ++ [{fname, path}]})}
  end

  @impl true
  def handle_cast({:stop}, %{port: port} = state) do
    Cmd.exit(port)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:dequeue, target_path}, %{queue: queue} = state) do
    notify_state_change()
    q = Enum.reject(queue, fn {_, path} -> path == target_path end)

    {:noreply, Map.merge(state, %{queue: q})}
  end

  @impl true
  def handle_info({_, {:exit_status, _}}, %{queue: []} = state) do
    notify_state_change()
    {:noreply, %{current_file: nil, port: nil, path: nil, queue: []}}
  end

  @impl true
  def handle_info({_, {:exit_status, _}}, %{queue: [{fname, path} | queue]} = state) do
    notify_state_change()
    Vlc.Player.play(fname, path)
    {:noreply, %{current_file: nil, port: nil, path: nil, queue: queue}}
  end
end
