module View exposing (..)

import List exposing (..)
import Color exposing (..)
import Html
import Svg exposing (..)
import Svg.Attributes exposing (..)
import List.Nonempty as NE exposing (Nonempty, (:::))
import Debug

import Land
import Hex exposing (landPath)

board : (Int, Int) -> Land.Map -> Html.Html msg
board (w,h) lands =
  svg
    [ toString w |> width, toString h |> height, viewBox "0 0 800 800" ]
    -- (NE.append
    (NE.toList (NE.map landSvg (Debug.log "lands" lands)))
    -- (NE.concat <| NE.map pointSvg lands)
    -- |> NE.toList
    -- )
    -- [ polyline [ fill "none", stroke "black", points (polyPoints w h ((NE.head lands) .hexagons)) ] [] ]



landSvg : Land.Land -> Svg msg
landSvg land =
  polygon [ fill "darkred", stroke "black", strokeLinejoin "round", strokeWidth "10",
    points (Debug.log "path" (landPointsString land.hexagons)) ] []

landPointsString : Land.Cells -> String
landPointsString cells =
--  "1,1 10,10"
  landPath 2 1 cells
  |> NE.map (\p -> ((fst p) * 100, (snd p) * 100))
  -- |> closePath
  |> NE.map (\p -> (fst p |> toString) ++ "," ++ (snd p |> toString) ++ " ")
  |> NE.foldl (++) ""
  |> Debug.log "svg attr path"

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
    ::: (text' [x x', y y'] [text <| x' ++ "," ++ y' ]
        |> NE.fromElement)
  )
  |> NE.concat
  
  -- <circle cx="10" cy="10" r="2" fill="red"/> 
  
--  |> NE.map (\p -> (fst p |> toString) ++ "," ++ (snd p |> toString))
--  |> NE.foldl (++) ""

-- polyPoints : Int -> Int -> Land.Cells -> String
-- polyPoints w h lands =
--   "1,1 10,10"

-- board : (Int, Int) -> Land.Map -> Element
-- board (w,h) lands =
--   ([]
--    ++ (landForms w h lands |> NE.toList)
--   --  ++ (gridLine w h 5)
--   --  ++ (gridLine w h 6)
--    )
--   |> map (origin w h)
--   |> collage w h

-- origin : Int -> Int -> Form -> Form
-- origin w h form =
--   move ((toFloat w / -2), (toFloat h / 2)) form

-- landForms : Int -> Int -> Land.Map -> NE.Nonempty Form
-- landForms w h lands =
--   NE.map (\l -> landForm l.hexagons) lands

-- landForm : Land.Cells -> Form
-- landForm hexagons =
--   NE.map (uncurry (hexagon 100 60)) hexagons
--   |> NE.concat
--   |> Debug.log "form"
--   |> NE.toList
--   |> polygon
--   |> outlined (dashed red)


-- -- gridLine : Int -> Int -> Int -> List Form
-- -- gridLine w h row =
-- --   let
-- --     hex = flip (hexagon 100) -- hexagon 100 y x
-- --   in
-- --     map (hex (row * -1) >> filled blue) [0..2]
