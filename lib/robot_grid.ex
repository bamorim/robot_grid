defmodule RobotGrid do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      Plug.Adapters.Cowboy.child_spec(:http, RobotGrid.Router, [], [
        port: 5555,
        dispatch: dispatch
      ])
    ]

    Supervisor.start_link(children, [strategy: :one_for_one, name: RobotGrid.Supervisor])
  end

  def dispatch do
    [
      {:_, [
        {"/ws", RobotGrid.SocketHandler, []},
        {:_, Plug.Adapters.Cowboy.Handler, {RobotGrid.Router, []}}
      ]}
    ]
  end
end
