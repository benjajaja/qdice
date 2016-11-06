module Board exposing (..)

import Svg exposing (..)
import Svg.Attributes exposing (..)
import Svg.Events exposing (..)
import Color exposing (..)
import Color.Convert exposing (..)
import Color.Manipulate exposing (..)
import Html

import Hexagons.Layout exposing (orientationLayoutPointy, Layout)

import Hex exposing (Point)
import Land exposing (Land, Map, landPath, center)



type Msg
  = Resize (Int, Int)
  | ClickLand (Land.Land)
  | HoverLand Land.Land
  | UnHoverLand Land.Land

type alias Model =
  { size: (Int, Int)
  , map: Map
  }


init : (Model, Cmd Msg)
init =
  (Model (850, 600) (Land.fullCellMap 4 4), Cmd.none)

view : Model -> Html.Html Msg
view model =
  board model.size model.map

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  let
    {size, map} = model
  in
    case msg of
      Resize size ->
        (Model size map, Cmd.none)
      ClickLand (land) ->
        (Model size (Land.landColor map land Land.Editor), Cmd.none)
      HoverLand land ->
        let
          map' = Land.highlight True map land -- |> Debug.log "hilite"
        in
          if map' /= map then
            let _ = Debug.log "hilite" <| List.length map'.lands
            in (Model size map', Cmd.none)
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

heightScale : Float
heightScale = 0.5

padding : Float
padding = 3


board : (Int, Int) -> Land.Map -> Svg Msg
board (w, h) map =
  let
    cellWidth = (toFloat w - padding) / (((toFloat map.width) + 0.5)) -- actual cell width
    cellHeight = cellWidth * heightScale -- 0.75 + (cellWidth * 0.25) |> round |> toFloat
    sWidth = toString w
    sHeight = cellHeight * 0.75 * (toFloat map.height + 1 / 3) + padding |> toString
    _ = Debug.log "height" (cellWidth |> floor, cellHeight |> floor, map.height, sHeight)
  in
    Svg.svg
      [
        width sWidth
        , height sHeight
        , viewBox ("0 0 " ++ sWidth ++ " " ++ sHeight)
        -- , Svg.Attributes.style "border: 1px solid red"
      ]
      (List.map (landSvg (myLayout (cellWidth / sqrt(3), cellWidth * heightScale / 2) padding)) map.lands)
      
      

myLayout : (Float, Float) -> Float -> Hexagons.Layout.Layout
myLayout (cellWidth, cellHeight) padding =
  { orientation = orientationLayoutPointy
  , size = Debug.log "size" (cellWidth, cellHeight)
  , origin = (padding / 2, -cellHeight / 2 + padding / 2)
  }

landSvg : Hexagons.Layout.Layout -> Land.Land -> Svg Msg
landSvg layout land =
  let
    path = landPath layout land.hexagons
    (x'', y'') = center layout land.hexagons
    x' = toString x''
    y' = toString y''
  in
    g [] ([ polygon [ fill <| landColor land
      , stroke "black"
      , strokeLinejoin "round", strokeWidth (2 |> toString)
      , points (landPointsString path)
      , onClick (ClickLand (land))
      , onMouseOver (HoverLand land)
      , onMouseOut (UnHoverLand land)
      ] []
    -- , text' [x (toString (x'' + 10)), y (toString (y'' + 10))] [Svg.text <| x' ++ "," ++ y' ]
    ])

landPointsString : List Hex.Point -> String
landPointsString path =
  path |> List.foldl addPointToString ""

addPointToString : Hex.Point -> String -> String
addPointToString point path =
  path ++ (pointToString point) ++ " "

pointToString : Hex.Point -> String
pointToString (x, y) = (x |> toString) ++ "," ++ (y |> toString)

landColor : Land -> String
landColor land =
  svgColor land.selected land.color

svgColor : Bool -> Land.Color -> String
svgColor highlight color =
  (case color of
    Land.Neutral -> Color.rgb 243 0 242
    Land.Editor  -> Color.rgb 255 0 0
    Land.Black   -> Color.rgb 52 52 52
    Land.Red     -> Color.rgb 196 2 51
    Land.Green   -> Color.rgb 0  159  107
    Land.Blue    -> Color.rgb 0  135  189
    Land.Yellow  -> Color.rgb 255  211  0
    Land.Magenta -> Color.rgb 187 86 149
    Land.Cyan    -> Color.rgb 103 189 170
  )
  |> Color.Manipulate.lighten (if highlight then 0.5 else 0.0)
  |> Color.Convert.colorToCssRgb
