defmodule RobotGrid.Robot do
  defmodule State do
    defstruct time: 0.0, pos: {0.0,0.0}, speed: {0.0,0.0}

    def new({x,y} \\ {0,0}, {sx, sy} \\ {0,0}) do
      %State{time: :os.system_time, pos: {x*1.0, y*1.0}, speed: {sx*1.0, sy*1.0}}
    end

    def tick(%State{time: time, pos: {x,y}, speed: {sx, sy}}) do
      newtime = :os.system_time
      dt = newtime - time
      dx = dt*1.0e-9*sx
      dy = dt*1.0e-9*sy
      newpos = {x+dx, y+dy}
      %State{time: newtime, pos: newpos, speed: {sx, sy}}
    end

    def set_speed(state, spd), do: %State{state | speed: spd}
  end

  use GenServer

  # Public API

  def start_link(args \\ []) do
    GenServer.start_link __MODULE__, args
  end

  def set_speed(pid, spd) do
    GenServer.cast pid, {:set_speed, spd}
  end

  def get_pos(pid) do
    GenServer.call pid, :get_pos
  end

  def stop(pid), do: GenServer.stop pid

  # Callbacks

  def init(args) do
    pos = Keyword.get(args, :pos, {0,0})
    speed = Keyword.get(args, :speed, {0,0})
    {:ok, State.new(pos, speed)}
  end

  def handle_cast({:set_speed, spd}, state) do
    newstate = state
    |> State.tick
    |> State.set_speed(spd)
    {:noreply, newstate}
  end

  def handle_call(:get_pos, _from, state) do
    newstate = state |> State.tick

    {:reply, newstate.pos, newstate}
  end
end
