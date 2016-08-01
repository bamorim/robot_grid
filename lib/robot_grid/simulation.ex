defmodule RobotGrid.Simulation do
  alias RobotGrid.{Robot, Controller}

  defmodule RobotConfig do
    defstruct origin: {0,0}, rates: {1,1,1,1}
  end

  def start_all(configs) do
    robots_with_configs = configs
    |> Enum.map(&({start_robot!(&1), &1}))

    processes_with_target = robots_with_configs
    |> Enum.map(&start_processes!/1)

    # Link processes by robot
    processes_with_target
    |> Enum.map(&(Enum.map(&1, fn {p, _t} -> p end)))
    |> Enum.each(&link_processes/1)

    # Link processes by target
    processes_with_target
    |> List.flatten
    |> Enum.group_by(fn {_, t} -> t end, fn {p, _} -> p end)
    |> Map.values
    |> Enum.each(&link_processes/1)

    robots = robots_with_configs |> Enum.map(fn {r, _} -> r end)
    processes = processes_with_target |> List.flatten |> Enum.map(fn {p, _} -> p end)

    processes
    |> Enum.each(&Controller.run/1)

    {robots, processes}
  end

  defp start_robot!(config) do
    {:ok, robot} = Robot.start_link(pos: config.origin)
    robot
  end

  defp start_processes!({robot, config}) do
    {left_r, up_r, right_r, down_r} = config.rates

    left  = start_process!(robot, config.origin, {-1, 0}, left_r)
    up    = start_process!(robot, config.origin, {0, -1}, up_r)
    right = start_process!(robot, config.origin, {1, 0}, right_r)
    down  = start_process!(robot, config.origin, {0, 1}, down_r)

    [left, up, right, down]
  end

  defp start_process!(robot, {x,y}, {dx, dy}, rate) do
    target = {x+dx, y+dy}
    {:ok, process} = Controller.start_link(robot, {x,y}, target, rate)
    {process, target}
  end

  defp link_processes([]), do: nil
  defp link_processes([p|t]) do
    Enum.each(t, &(Controller.link(p, &1)))
    link_processes(t)
  end
end
