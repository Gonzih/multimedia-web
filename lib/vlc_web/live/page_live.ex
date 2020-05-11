defmodule VlcWeb.PageLive do
  use VlcWeb, :live_view

  @dirs ["/video"]

  defp clean_string(s1), do: String.replace(s1, ".", " ")
  defp calc_distance(s1, s2), do: String.jaro_distance(String.downcase(s1), String.downcase(s2))

  @impl true
  def mount(_params, _session, socket) do
    send(self(), :reload)
    {:ok, assign(socket, directories: @dirs, query: "", results: [], suggestions: [], loading: true, vlc_port: nil, current_file: nil)}
  end

  @impl true
  def handle_event("suggest", %{"q" => ""}, %{assigns: %{results: results}} = socket) do
    {:noreply, assign(socket, suggestions: results)}
  end

  defp filter_suggestions(results, query) do
    results
    |> Enum.sort_by(
      fn {fname, _} -> calc_distance(clean_string(fname), query) end
    )
    |> Enum.reverse()
  end


  @impl true
  def handle_event("suggest", %{"q" => query}, %{assigns: %{results: results}} = socket) do
    {:noreply, assign(socket, suggestions: filter_suggestions(results, query), query: query)}
  end

  @impl true
  def handle_event("reload", _, socket) do
    send(self(), :reload)
    {:noreply, assign(socket, loading: true)}
  end

  @impl true
  def handle_event("stop", _, %{assigns: %{vlc_port: vlc_port}} = socket) do
    Vlc.exit(vlc_port)
    {:noreply, socket}
  end

  @impl true
  def handle_event("play", %{"path" => path, "fname" => fname}, socket) do
    port = Vlc.play(path)
    {:noreply, assign(socket, vlc_port: port, current_file: fname)}
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
  def handle_info({_, {:exit_status, _}}, socket) do
    {:noreply, assign(socket, vlc_port: nil, current_file: nil)}
  end
end

defmodule Vlc do
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
