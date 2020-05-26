defmodule MediaWeb.PageLive do
  use MediaWeb, :live_view
  alias Phoenix.PubSub

  @topic "media-outgoing"
  @volume_value 20

  defp prepare_string(s),
    do: s
    |> String.replace(".", " ")
    |> String.replace("/", " ")
    |> String.downcase
    |> String.split(" ")
    |> Enum.uniq

  defp number_of_matches(list, queries) do
    bools = for s1 <- list, s2 <- queries do
      String.contains?(s1, s2) && String.length(s1) > 0 && String.length(s2) > 0
    end

    bools |> Enum.filter(fn b -> b end)
  end

  defp match_string(path, query) do
    p = prepare_string(path)
    q = prepare_string(query)
    matches = number_of_matches(p, q)

    Enum.count(matches) >= Enum.count(q)
  end

  defp filter_suggestions(results, ""),
    do: results

  defp filter_suggestions(results, query) do
    results
    |> Enum.filter(
      fn {_fname, path} -> match_string(path, query) end
    )
    |> Enum.sort()
  end

  @impl true
  def mount(_params, _session, socket) do
    PubSub.subscribe(Media.PubSub, @topic)

    file = Media.Player.current_file()
    queue = Media.Player.queue()
    results = Media.Player.all_files()
    {:ok, dir} = System.fetch_env("TARGET_DIRECTORY")
    dirs = [dir]

    if Enum.count(results) == 0 do
      Media.Player.reload_files(dirs)
    end

    {:ok, assign(socket,
      directories: dirs,
      query: "",
      results: results,
      suggestions: results,
      loading: false,
      queue: queue,
      current_file: file)}
  end

  @impl true
  def handle_event("suggest", %{"q" => query}, %{assigns: %{results: results}} = socket) do
    {:noreply, assign(socket, suggestions: filter_suggestions(results, query), query: query, loading: false)}
  end

  @impl true
  def handle_event("reload", _, %{assigns: %{directories: dirs}} = socket) do
    Media.Player.reload_files(dirs)
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

  @imlp true
  def handle_event("clear_filter", _, %{assigns: %{results: results}} = socket) do
    {:noreply, assign(socket, suggestions: filter_suggestions(results, ""), query: "", loading: false)}
  end

  @impl true
  def handle_info(
    %{topic: @topic, payload: :state_change},
    socket
  ) do
    file = Media.Player.current_file()
    queue = Media.Player.queue()
    {:noreply, socket |> assign(current_file: file, queue: queue, loading: false)}
  end

  @impl true
  def handle_info(
    %{topic: @topic, payload: :files_reload},
    %{assigns: %{query: query}} = socket
  ) do
    results = Media.Player.all_files()
    {:noreply, socket |> assign(results: results, suggestions: filter_suggestions(results, query), loading: false)}
  end
end
