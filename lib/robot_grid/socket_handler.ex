defmodule RobotGrid.SocketHandler do
  alias RobotGrid.{Robot, Controller}
  @behaviour :cowboy_websocket_handler

  def init(_, _req, _opts) do
    {:upgrade, :protocol, :cowboy_websocket}
  end

  @timeout 60000
  @timer_interval 16
  @grid_size 4
  @max_laziness 4

  # WebSocket API

  def websocket_init(_type, req, _opts) do
    # Initialize Robots
    robots_with_origin = 0..(@grid_size*@grid_size - 1)
    |> Enum.map(&(start_robot(self, &1)))

    processes_with_target = robots_with_origin
    |> Enum.flat_map(&start_processes/1)

    # Link processes by target
    processes_with_target
    |> Enum.group_by(fn {t, _} -> t end, fn {_, p} -> p end)
    |> Map.values
    |> Enum.each(&link_processes/1)

    robots = robots_with_origin |> Enum.map(fn {_, r} -> r end)
    processes = processes_with_target |> Enum.map(fn {_, p} -> p end)

    # Start end processes
    processes
    |> Enum.each(&Controller.run/1)

    # Setup update timer
    {:ok, timer} = :timer.apply_interval(@timer_interval, __MODULE__, :update_positions, [self, robots])

    {:ok, req, {robots, processes, timer}, @timeout}
  end

  def websocket_handle({:text, txt}, req, state) do
    {:reply, {:text, txt}, req, state}
  end

  def websocket_info({id,{x,y}}, req, state) when is_number(id) and is_number(x) and is_number(y) do
    {:reply, {:text, "#{id},#{x},#{y}"}, req, state}
  end
  def websocket_info(_info, req, state), do: {:ok, req, state}

  def websocket_terminate(_reason, _req, {robots, processes, timer}) do
    IO.puts "Terminating..."

    :timer.cancel(timer)
    processes |> Enum.each(&GenServer.stop/1)
    robots |> Enum.each(&Robot.stop/1)

    :ok
  end

  # Robot Control

  def start_processes(robot_with_pos) do
    processes = [{-1,0}, {0,-1}, {1,0}, {0,1}]
    |> Enum.map(&(start_process(robot_with_pos, &1)))

    # Link processes that share the same robot
    processes
    |> Enum.map(fn {_,p} -> p end)
    |> link_processes

    processes
  end

  def start_process({{x,y}, robot}, {dx, dy}) do
    target = {x+dx, y+dy}
    laziness = :random.uniform * @max_laziness |> Float.ceil |> trunc
    {:ok, process} = Controller.start_link(robot, {x,y}, target, laziness)
    {target, process}
  end

  def link_processes([]), do: nil
  def link_processes([p|t]) do
    Enum.each(t, &(Controller.link(p, &1)))
    link_processes(t)
  end

  def start_robot(socket, id) do
    y = div(id, @grid_size)
    x = rem(id, @grid_size) * 2 + rem(y, 2)
    {:ok, rbt} = Robot.start_link pos: {x+1, y+1}

    {{x+1,y+1},rbt}
  end

  def update_positions(socket, robots) do
    robots
    |> Enum.with_index
    |> Enum.each(fn {rbt, id} -> update_position(socket, id, rbt) end)
  end

  def update_position(socket, id, rbt) do
    send socket, {id, Robot.get_pos(rbt)}
  end
end
