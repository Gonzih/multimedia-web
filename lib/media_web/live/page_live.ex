defmodule MediaWeb.PageLive do
  use MediaWeb, :live_view
  alias Phoenix.PubSub

  @topic "media-outgoing"
  @volume_value 20

  defp clean_string(s), do: String.replace(s, ".", " ")
  defp calc_distance(s1, s2), do: String.jaro_distance(String.downcase(s1), String.downcase(s2))

  defp filter_suggestions(results, ""),
    do: results

  defp filter_suggestions(results, query) do
    results
    |> Enum.sort_by(
      fn {fname, _path} -> calc_distance(query, clean_string(fname)) end
    )
    |> Enum.reverse()
    |> Enum.take(50)
  end

  @impl true
  def mount(_params, _session, socket) do
    PubSub.subscribe(Media.PubSub, @topic)

    file = Media.Player.current_file()
    queue = Media.Player.queue()
    {:ok, dir} = System.fetch_env("TARGET_DIRECTORY")

    send(self(), :reload)
    {:ok, assign(socket,
      directories: [dir],
      query: "",
      results: [],
      suggestions: [],
      loading: true,
      queue: queue,
      current_file: file)}
  end

  @impl true
  def handle_event("suggest", %{"q" => query}, %{assigns: %{results: results}} = socket) do
    {:noreply, assign(socket, suggestions: filter_suggestions(results, query), query: query, loading: false)}
  end

  @impl true
  def handle_event("reload", _, socket) do
    send(self(), :reload)
    {:noreply, assign(socket, loading: true)}
  end

  @impl true
  def handle_event("stop", _, socket) do
    Media.Player.stop()
    {:noreply, socket}
  end

  @impl true
  def handle_event("play", %{"path" => path, "fname" => fname}, socket) do
    Media.Player.play(fname, path)
    {:noreply, socket}
  end

  @impl true
  def handle_event("dequeue", %{"path" => path}, socket) do
    Media.Player.dequeue(path)
    {:noreply, socket}
  end

  @impl true
  def handle_event("dequeue_all", _, socket) do
    Media.Player.dequeue_all()
    {:noreply, socket}
  end

  @imlp true
  def handle_event("pause", _, socket) do
    Media.Player.command("pause")
    {:noreply, socket}
  end

  @imlp true
  def handle_event("switch_audio", _, socket) do
    Media.Player.command("switch_audio")
    {:noreply, socket}
  end

  @imlp true
  def handle_event("switch_subtitle", _, socket) do
    Media.Player.command("sub_select")
    {:noreply, socket}
  end

  @imlp true
  def handle_event("switch_audio", _, socket) do
    Media.Player.command("switch_audio")
    {:noreply, socket}
  end

  @imlp true
  def handle_event("volume_up", _, socket) do
    Media.Player.command("volume +#{@volume_value}")
    {:noreply, socket}
  end

  @imlp true
  def handle_event("volume_down", _, socket) do
    Media.Player.command("volume -#{@volume_value}")
    {:noreply, socket}
  end

  @impl true
  def handle_info(:reload, %{assigns: %{directories: dirs, query: query}} = socket) do
    results = dirs
              |> FlatFiles.ls()
              |> Enum.reject(&String.match?(&1, ~r/\.(png|jpg|ogg|lua|exe|txt|ds_store|vob|bup|ifo|xml|toc|ass|srt)$/i))
              |> Enum.reject(&String.match?(&1, ~r/\/\._/i))
              |> Enum.map(fn p -> {Path.basename(p), Path.absname(p)} end)

    {:noreply, assign(socket, results: results, suggestions: filter_suggestions(results, query), loading: false)}
  end

  @impl true
  def handle_info(
    %{topic: @topic, payload: :state_changed},
    socket
  ) do
    file = Media.Player.current_file()
    queue = Media.Player.queue()
    {:noreply, socket |> assign(current_file: file, queue: queue, loading: false)}
  end
end

defmodule FlatFiles do# {{{
  def list_all(filepath) do
    _list_all(filepath)
  end

  defp _list_all(filepath) do
    cond do
      String.contains?(filepath, ".git") -> []
      true -> expand(File.ls(filepath), filepath)
    end
  end

  defp expand({:ok, files}, path) do
    files
    |> Enum.flat_map(&_list_all("#{path}/#{&1}"))
  end

  defp expand({:error, _}, path) do
    [path]
  end

  def ls(paths), do: expand({:ok, paths}, "/")
end# }}}
