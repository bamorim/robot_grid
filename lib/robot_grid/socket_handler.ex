defmodule RobotGrid.SocketHandler do
  alias RobotGrid.Robot
  @behaviour :cowboy_websocket_handler

  def init(_, _req, _opts) do
    {:upgrade, :protocol, :cowboy_websocket}
  end

  @timeout 60000
  @timer_interval 16
  @grid_size 4

  # WebSocket API

  def websocket_init(_type, req, _opts) do
    # Initialize Robots
    robots = 0..(@grid_size*@grid_size - 1)
    |> Enum.map(&(start_robot(self, &1)))

    robot_spots = for {spot, _} <- robots, into: MapSet.new, do: spot

    rng = 0..(@grid_size*2 + 1)
    spots = for x <- rng, y <- rng, not MapSet.member?(robot_spots, {x,y}), do: {x,y}

    # Setup update timer
    {:ok, timer} = :timer.apply_interval(@timer_interval, __MODULE__, :update_positions, [self, robots])
    {:ok, req, {robots, timer}, @timeout}
  end

  def websocket_handle({:text, txt}, req, state) do
    {:reply, {:text, txt}, req, state}
  end

  def websocket_info({id,{x,y}}, req, state) when is_number(id) and is_number(x) and is_number(y) do
    {:reply, {:text, "#{id},#{x},#{y}"}, req, state}
  end
  def websocket_info(_info, req, state), do: {:ok, req, state}

  def websocket_terminate(_reason, _req, {robots, timer}) do
    IO.puts "Terminating..."
    robots
    |> Enum.each(fn {_,rbt} -> Robot.stop(rbt) end)
    :timer.cancel(timer)
    :ok
  end

  # Robot Control

  def start_robot(socket, id) do
    y = div(id, @grid_size)
    x = rem(id, @grid_size) * 2 + rem(y, 2)
    {:ok, rbt} = Robot.start_link pos: {x+1, y+1}

    {{x,y},rbt}
  end

  def update_positions(socket, robots) do
    robots
    |> Enum.with_index
    |> Enum.each(fn {{_,rbt}, id} -> update_position(socket, id, rbt) end)
  end

  def update_position(socket, id, rbt) do
    send socket, {id, Robot.get_pos(rbt)}
  end
end
