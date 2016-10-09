module Board exposing (..)

import Svg exposing (..)
import Svg.Attributes exposing (..)
import Svg.Events exposing (..)
import Color exposing (..)
import Color.Convert exposing (..)
import Color.Manipulate exposing (..)
import Html

import Hex exposing (landPath)
import Land exposing (Land, Map)


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
  (Model (800, 600) (Land.fullCellMap 30 20), Cmd.none)

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
            let _ = Debug.log "hilite" ""
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


board : (Int, Int) -> Land.Map -> Svg Msg
board size map =
  let
    w = fst size |> (+) -1 |> toString
    -- h = snd size |> (+) -100 |> toString
    h = "500"
    cellWidth = Debug.log "cellWidth" <| (fst size |> toFloat) / (toFloat map.width)
  in
    Svg.svg
      [ width w, height h, viewBox ("0 0 " ++ w ++ " " ++ h) ]
      -- (NE.append
      (List.map (landSvg cellWidth) map.lands)
      -- ++ (NE.toList (NE.concat <| NE.map pointSvg lands))
      -- |> NE.toList
      -- )
      -- [ polyline [ fill "none", stroke "black", points (polyPoints w h ((NE.head lands) .hexagons)) ] [] ]



landSvg : Float -> Land.Land -> Svg Msg
landSvg cellWidth land =
  let
    path = landPath 1 0.5 land.hexagons
  in
    g [] ([ polyline [ fill <| landColor land
      , stroke "black"
      , strokeLinejoin "round", strokeWidth (cellWidth / 15 |> toString)
      , points (landPointsString path cellWidth)
      , onClick (ClickLand (land))
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

landPointsString : List Hex.Point -> Float -> String
landPointsString path cellWidth =
--  "1,1 10,10"
  path
  |> List.map (\p -> ((fst p) * cellWidth, (snd p) * cellWidth))
  -- |> closePath
  |> List.map (\p -> (fst p |> toString) ++ "," ++ (snd p |> toString) ++ " ")
  |> List.foldl (++) ""
  -- |> Debug.log "svg attr path"

-- closePath : List Hex.Point -> List Hex.Point
-- closePath cells =
--   case cells of
--     [] -> []
--     [one] -> [one]
--     hd::_ -> List.append cells [hd]

-- pointSvg : Land.Land -> List (Svg msg)
-- pointSvg land =
--   landPath 100 50 land.hexagons
--   |> List.map (\p ->
--     let
--       x' = (fst p |> toString)
--       y' = (snd p |> toString)
--     in
--     circle [ r "2", fill "red", cx x', cy y' ] []
--     :: ([text' [x x', y y'] [Svg.text <| x' ++ "," ++ y' ]])
--   )
--   |> List.concat

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
