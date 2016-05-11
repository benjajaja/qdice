module View (..) where

import List exposing (..)
import Color exposing (..)
import Graphics.Element exposing (..)
import Graphics.Collage exposing (..)
import List.Nonempty as NE exposing (Nonempty, (:::))
import Debug

import Land
import Hex exposing (hexagon)

board : (Int, Int) -> Land.Map -> Element
board (w,h) lands =
  ([]
   ++ (landForms w h lands |> NE.toList)
  --  ++ (gridLine w h 5)
  --  ++ (gridLine w h 6)
   )
  |> map (origin w h)
  |> collage w h

origin : Int -> Int -> Form -> Form
origin w h form =
  move ((toFloat w / -2), (toFloat h / 2)) form

landForms : Int -> Int -> Land.Map -> NE.Nonempty Form
landForms w h lands =
  NE.map (\l -> landForm l.hexagons) lands

landForm : Land.Cells -> Form
landForm hexagons =
  NE.map (uncurry (hexagon 100 60)) hexagons
  |> NE.concat
  |> Debug.log "form"
  |> NE.toList
  |> polygon
  |> outlined (dashed red)


-- gridLine : Int -> Int -> Int -> List Form
-- gridLine w h row =
--   let
--     hex = flip (hexagon 100) -- hexagon 100 y x
--   in
--     map (hex (row * -1) >> filled blue) [0..2]
