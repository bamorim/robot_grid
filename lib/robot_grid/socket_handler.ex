defmodule RobotGrid.SocketHandler do
  alias RobotGrid.{Simulation, Robot}
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
    configs = 0..(@grid_size*@grid_size-1) |> Enum.map(&config_robot/1)

    # Start simulation
    {robots, processes} = Simulation.start_all(configs)

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
    robots |> Enum.each(&GenServer.stop/1)

    :ok
  end

  # Robot Control

  defp config_robot(id) do
    y = div(id, @grid_size)
    x = rem(id, @grid_size) * 2 + rem(y, 2)
    origin = {x+1, y+1}
    rates = {random_rate, random_rate, random_rate, random_rate}
    %Simulation.RobotConfig{origin: origin, rates: rates}
  end

  defp random_rate, do: :random.uniform * @max_laziness |> Float.ceil |> trunc

  def update_positions(socket, robots) do
    robots
    |> Enum.with_index
    |> Enum.each(fn {rbt, id} -> update_position(socket, id, rbt) end)
  end

  def update_position(socket, id, rbt) do
    send socket, {id, Robot.get_pos(rbt)}
  end
end
