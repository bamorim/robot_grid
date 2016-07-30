import Html exposing (Html)
import Html.App as App
import Dict exposing (Dict)
import Svg exposing (Svg, svg, circle)
import Svg.Attributes exposing (cx, cy, r, fill, width, viewBox)
import String
import WebSocket

main =
  App.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

botServer : String
botServer =
  "ws://localhost:5555/ws"

-- MODEL
type alias Pos =
  { x : Float
  , y : Float
  }

type alias Model =
  Dict Int Pos


init : (Model, Cmd Msg)
init =
  (Dict.empty, Cmd.none)

-- UPDATE

type Msg =
  SocketMessage String

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    SocketMessage str ->
      (model |> (updatePositions (parseUpdate str)), Cmd.none)

parseUpdate : String -> Maybe (Int, Pos)
parseUpdate str =
  case String.split "," str of
    [id,x,y] -> Result.toMaybe
                ( Result.map2 (,) (String.toInt id)
                  (Result.map2 Pos (String.toFloat x) (String.toFloat y)))
    _ -> Nothing

updatePositions : Maybe (Int, Pos) -> Model -> Model
updatePositions up =
  case up of
    Just (id, pos) -> Dict.insert id pos
    Nothing -> identity

-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  WebSocket.listen botServer SocketMessage

-- VIEW

view : Model -> Html Msg
view model =
  svg [viewBox "-1 -1 50 50", width "1000px"]
    (model |> Dict.toList |> (List.map viewRobot'))

viewRobot' : (Int, Pos) -> Svg Msg
viewRobot' (_, pos) =
  viewRobot pos

viewRobot : Pos -> Svg Msg
viewRobot {x,y} =
  circle [cx (toString x), cy (toString y), r "0.4", fill "#FF0000"] []
