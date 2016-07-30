defmodule RobotGrid.Controller do
  defmodule RobotConfig, do: defstruct robot: nil, laziness: 1, origin: {0,0}, target: {0,0}
  defmodule State, do: defstruct robot_config: nil, state: :idle, connections: [], coins: %{}

  alias RobotGrid.Robot

  @delta 0.01
  @speed 10

  use GenServer

  def start_link(robot, origin, target, laziness \\ 1) do
    config = %RobotConfig{robot: robot, laziness: laziness, origin: origin, target: target}
    GenServer.start_link __MODULE__, config
  end

  def link(pid1, pid2) do
    GenServer.call pid1, {:link_to, pid2}
  end

  def run(pid) do
    GenServer.cast pid, :run
  end

  # GenServer Callbacks
  def init(robot_config) do
    {:ok, %State{robot_config: robot_config}}
  end

  def handle_call({:link_to, neighbor}, _from, state) do
    coins = GenServer.call neighbor, {:connect, state.robot_config.laziness}
    new_state = state |> add_connection(neighbor, coins)
    {:reply, :ok, new_state}
  end
  def handle_call({:connect, neighbor_laziness}, {neighbor, _tag}, state) do
    coins = max(neighbor_laziness, state.robot_config.laziness)
    new_state = state |> add_connection(neighbor, coins)
    {:reply, 0, new_state}
  end

  def handle_cast({:coins, neighbor, coins}, state) do
    new_state = state
    |> update_coins(neighbor, &(&1+coins))
    |> run_if_ready

    {:noreply, new_state}
  end
  def handle_cast(:run, state), do: {:noreply, run_if_ready(state)}

  # Internals

  defp run_if_ready(state) do
    if ready_to_start?(state) do
      run!(state.robot_config)

      state
      |> update_coins(&(&1 - state.robot_config.laziness))
      |> give_coins
    else
      state
    end
  end

  defp ready_to_start?(state) do
    state.coins |> Map.values |> Enum.all?(&(&1 >= state.robot_config.laziness))
  end

  defp run!(%RobotConfig{origin: origin, target: target, robot: robot}) do
    {dx, dy} = get_dir(origin, target)

    Robot.set_speed(robot, {dx, dy})
    wait_pos(robot, target, {dx, dy})

    Robot.set_speed(robot, {0-dx, 0-dy})
    wait_pos(robot, origin, {0-dx, 0-dy})

    Robot.set_speed(robot, {0,0})
  end

  defp wait_pos(robot, {tx, ty}, {dx, dy}) do
    {x, y} = Robot.get_pos(robot)
    if (tx - x)*dx > @delta or (ty - y)*dy > @delta do
      :timer.sleep(1)
      wait_pos(robot, {tx, ty}, {dx, dy})
    end
  end

  defp get_dir({ox, oy}, {tx, ty}) do
    if ox == tx do
      if ty > oy do
        {0, 1*@speed}
      else
        {0, -1*@speed}
      end
    else
      if tx > ox do
        {1*@speed, 0}
      else
        {-1*@speed, 0}
      end
    end
  end

  # State manipulation

  defp add_connection(state, neighbor, start_coins) do
    connections = [neighbor | state.connections]
    coins = state.coins |> Map.put(neighbor, start_coins)
    %State{state | connections: connections, coins: coins}
  end

  defp update_coins(state, fun) do
    Enum.reduce(state.connections, state, &(update_coins(&2, &1, fun)))
  end
  defp update_coins(state, neighbor, fun) do
    new_coins = Map.update!(state.coins, neighbor, fun)
    %State{state | coins: new_coins}
  end

  defp give_coins(state) do
    state.connections
    |> Enum.each(fn conn -> GenServer.cast conn, {:coins, self, state.robot_config.laziness} end)

    state
  end
end
