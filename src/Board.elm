module Board exposing (..)

import Svg exposing (..)
import Svg.Attributes exposing (..)
import Svg.Events exposing (..)
import List.Nonempty as NE exposing (Nonempty, (:::))
import Color exposing (..)
import Color.Convert exposing (..)
import Color.Manipulate exposing (..)
import Html
import Html.App as Html

import Hex exposing (landPath)
import Land exposing (..)



type Msg
  = Resize (Int, Int)
  | ClickLand (Land.Land, Land.Coord)
  | HoverLand Land.Land
  | UnHoverLand Land.Land

type alias Model =
  { size: (Int, Int)
  , map: Map
  }

main : Program Never
main =
  Html.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions --\_ -> Window.resizes sizeToMsg
    }

init : (Model, Cmd Msg)
init =
  (Model (800, 600) (Land.fullCellMap 30 20), Cmd.none)

view : Model -> Html.Html Msg
view model =
  board (fst model.size, snd model.size) model.map

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  let
    {size, map} = model
  in
    case msg of
      Resize size ->
        (Model size map, Cmd.none)
      ClickLand (land, cell) ->
        (Model size (Land.landColor map land Editor), Cmd.none)
      HoverLand land ->
        let
          map' = (Land.highlight True map land)
        in
          if map' /= map then (Model (Debug.log "highlight" size) map', Cmd.none)
          else (model, Cmd.none)
      UnHoverLand land ->
        let
          map' = (Land.highlight False map land)
        in
          if map' /= map then (Model size map', Cmd.none)
          else (model, Cmd.none)
      -- _ -> (model, Cmd.none)

subscriptions : Model -> Sub Msg
subscriptions model = Sub.none


board : (Int, Int) -> Land.Map -> Svg Msg
board size lands =
  let
    w = fst size |> (+) -100 |> toString
    h = snd size |> (+) -100 |> toString
  in
    Svg.svg
      [ width w, height h, viewBox ("0 0 " ++ w ++ " " ++ h) ]
      -- (NE.append
      (NE.toList (NE.map ((flip landSvg) ((fst size |> toFloat) / 50)) lands))
      -- ++ (NE.toList (NE.concat <| NE.map pointSvg lands))
      -- |> NE.toList
      -- )
      -- [ polyline [ fill "none", stroke "black", points (polyPoints w h ((NE.head lands) .hexagons)) ] [] ]



landSvg : Land.Land -> Float -> Svg Msg
landSvg land size =
  let
    path = landPath 2 1 land.hexagons
  in
    g [] ([ polyline [ fill <| landColor land
      , stroke "black"
      , strokeLinejoin "round", strokeWidth (size / 15 |> toString)
      , points (landPointsString path size)
      , onClick (ClickLand (land, NE.head land.hexagons))
      , onMouseOver (HoverLand land)
      , onMouseOut (UnHoverLand land)
      ] []
    -- , text' [x x', y y'] [Svg.text <| x' ++ "," ++ y' ]
    ]
    -- ++
    -- (NE.map (\p ->
    --   let
    --     (x'', y'') = Hex.hexpoint (2, 1) p NW
    --     x' = x'' * size |> toString
    --     y' = y'' * size + size / 2 |> toString
    --   in
    --     text' [x x', y y'] [Svg.text <| (fst p |> toString) ++ "," ++ (snd p |> toString) ]
    -- ) land.hexagons
    -- |> NE.toList)
    )

landPointsString : Nonempty Hex.Point -> Float -> String
landPointsString path cellSize =
--  "1,1 10,10"
  path
  |> NE.map (\p -> ((fst p) * cellSize, (snd p) * cellSize))
  -- |> closePath
  |> NE.map (\p -> (fst p |> toString) ++ "," ++ (snd p |> toString) ++ " ")
  |> NE.foldl (++) ""
  -- |> Debug.log "svg attr path"

closePath : NE.Nonempty Hex.Point -> NE.Nonempty Hex.Point
closePath cells = NE.append cells (NE.fromElement (NE.head cells))

pointSvg : Land.Land -> Nonempty (Svg msg)
pointSvg land =
  landPath 100 50 land.hexagons
  |> NE.map (\p ->
    let
      x' = (fst p |> toString)
      y' = (snd p |> toString)
    in
    circle [ r "2", fill "red", cx x', cy y' ] []
    ::: (text' [x x', y y'] [Svg.text <| x' ++ "," ++ y' ]
        |> NE.fromElement)
  )
  |> NE.concat

landColor : Land -> String
landColor land =
  svgColor land.selected land.color

svgColor : Bool -> Land.Color -> String
svgColor highlight color =
  (case color of
    Neutral -> Color.rgb 243 243 242
    Editor  -> Color.rgb 255 0 0
    Black   -> Color.rgb 52 52 52
    Red     -> Color.rgb 196 2 51
    Green   -> Color.rgb 0  159  107
    Blue    -> Color.rgb 0  135  189
    Yellow  -> Color.rgb 255  211  0
    Magenta -> Color.rgb 187 86 149
    Cyan    -> Color.rgb 103 189 170
  )
  |> Color.Manipulate.lighten (if highlight then 0.2 else 0.0)
  |> Color.Convert.colorToCssRgb