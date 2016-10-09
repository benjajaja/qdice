module Land exposing (..)

import Maybe exposing (..)
import List exposing (..)
-- import List.Nonempty as NE exposing (Nonempty, (:::))
import Random
import Hexagons.Hex as HH exposing (Hex, Direction, (===))
import Hexagons.Layout as HL exposing (offsetToHex)

type alias Cells = List Hex

type alias Land =
  { hexagons: Cells
  , color: Color
  , selected: Bool
  }

type alias Map =
  { lands: List Land
  , width: Int
  , height: Int
  }

type alias Border = (Hex, Direction)
type Color
  = Editor
  | Red
  | Green
  | Blue
  | Yellow
  | Magenta
  | Cyan
  | Black
  | Neutral


errorLand : Land
errorLand = Land [HL.offsetToHex (0, 0)] Editor False


fullCellMap : Int -> Int -> Map
fullCellMap w h =
  Map (List.map (\r ->
      List.map (\c ->
        { hexagons = [HL.offsetToHex (c, r)]
        , color = Neutral
        , selected = False}
      ) [0..w]
    ) [0..h]
    |> List.concat)
    w h
  -- |> List.filter (\l ->
  --   let head = l.hexagons |> NE.head
  --   in not (head == (1,1) || head == (1,0) || head == (0,1))
  -- )
  -- |> (::) 
  -- [{ hexagons = (1,1) ::: (1,0) ::: NE.fromElement (0,1)
  --   , color = Yellow
  --   , selected = False}]

offsetToHex : (Int, Int) -> Hex
offsetToHex (col, row) =
  HH.AxialHex (col - ((toFloat row) / 2 |> floor), row)

landColor : Map -> Land -> Color -> Map
landColor map land color =
  { map | lands = List.map (\l -> {l | color = if land == l then color else l.color }) map.lands }

highlight : Bool -> Map -> Land -> Map
highlight highlight map land =
  { map | lands = List.map (\l ->
    if l == land then { l | selected = highlight }
    else l -- { l | selected = False }
  ) map.lands }
    -- case filter (\l -> l /= land) map of
    --   Nothing -> NE.fromElement land'
    --   Just a -> land' ::: a

-- testLand =
--   NE.fromElement {hexagons =
--     (nonemptyList [
--        (0,0), (1,0), (2,0), (3,0)
--     ,     (0,1), (1,1), (2,1), (3,1)
--     ,  (0,2), (1,2), (2,2), (3,2)
--     ,     (0, 3), (1,3), (2,3)
--     ,  (0,4),        (2,4)
--     ,                    (2,5)
--     ] (0, 0))
--   }

-- filter lands in map with lambda


append : Map -> Land -> Map
append map land =
  { map | lands = List.append [land] map.lands }

-- indexOf helper
indexOf : List a -> (a -> Bool) -> Int
indexOf lst f =
  let
    helper : List a -> (a -> Bool) -> Int -> Int
    helper lst f offset = 
      case lst of
        []      -> -1
        x :: xs ->
          if f x then offset
          else helper xs f (offset + 1)
  in
    helper lst f 0


-- return index of coord in map
at : Map -> (Int, Int) -> Int
at map coord =
  let
    hex = HH.intFactory coord
    cb : Hex -> Land -> Bool
    cb hex land = any (\h -> h === hex) land.hexagons
    index = indexOf map.lands (cb hex)
  in
    index


-- concat all cells in map to a single neutral land
concat : Map -> Land
concat map =
  let
    hexes : Cells
    hexes = List.map (\l -> l.hexagons) map.lands |> List.concat
  in
    case head hexes of
      Nothing -> Land [] Neutral False
      Just hd -> Land hexes Neutral False


-- set one color to neutral
setNeutral : Map -> Color -> Map
setNeutral map color =
  { map | lands = List.map (\l -> { l | color = (if l.color == color then Neutral else l.color) }) map.lands }


playerColor : Int -> Color
playerColor i =
  case i of
    1 -> Red
    2 -> Green
    3 -> Blue
    4 -> Yellow
    5 -> Magenta
    6 -> Cyan
    7 -> Black
    0 -> Editor
    _ -> Neutral

randomPlayerColor : (Color -> a) -> Cmd a
randomPlayerColor v =
  -- Random.generate v (Random.int 1 7)
  Random.int 1 7 |> Random.map playerColor |> Random.generate v 

setColor : Map -> Land -> Color -> Map
setColor map land color =
  { map | lands = List.map (\l -> if l == land then { land | color = color } else l) map.lands }

allSides : List Direction
allSides = [HH.NW, HH.NE, HH.E, HH.SE, HH.SW, HH.W]


defaultSide : Direction
defaultSide = HH.NW

  
landBorders : Cells -> List Border
landBorders cells =
  case firstFreeBorder cells of
    Nothing -> []
    Just (coord, side) -> 
      if False && length cells == 1 then [(coord, rightSide side), (coord, side)]
      else
        nextBorders cells coord (coord, side) side [(coord, side)]


nextBorders : Cells -> Hex -> Border -> Direction -> List Border -> List Border
nextBorders cells coord origin side accum =
  let
    tco : Cells -> Hex -> Border -> Direction -> List Border -> Int -> List Border
    tco cells coord origin side accum fuse =
      let
        current = (coord, side)
      in
        if (fst origin === coord) && snd origin == side && List.length accum > 1 then
          (current :: accum)
        else if fuse == 0 then
          let _ = Debug.crash "TCO exhausted" (coord, side, origin, accum |> List.take 32, cells) in accum
        else
          case cellOnBorder coord side cells of
            Just c -> tco cells c origin (rightSide (oppositeSide side)) (accum) (fuse - 1)
            Nothing -> tco cells coord origin (rightSide side) (current :: accum) (fuse - 1)
  in
    tco cells coord origin side [] 1000
    |> List.reverse


rightSide : Direction -> Direction
rightSide side =
  case side of
    HH.NW -> HH.NE
    HH.NE -> HH.E
    HH.E -> HH.SE
    HH.SE -> HH.SW
    HH.SW -> HH.W
    HH.W -> HH.NW


oppositeSide : Direction -> Direction
oppositeSide =
  rightSide >> rightSide >> rightSide

hasCell : Cells -> Hex -> Bool
hasCell cells coord =
  any (\c -> c === coord) cells

firstFreeBorder : Cells -> Maybe Border
firstFreeBorder cells =
  case cells of
    [] -> Nothing
    hd::tl -> 
      case hasFreeBorder cells hd allSides of
        Just a -> Just (hd, a)
        Nothing -> firstFreeBorder tl


hasFreeBorder : Cells -> Hex -> List Direction -> Maybe Direction
hasFreeBorder cells coord sides =
  case sides of
    [] -> Nothing
    hd::tl ->
      if cellOnBorder coord hd cells |> isNothing then Just hd
      else if length sides == 1 then Just hd
      else hasFreeBorder cells coord tl


isNothing : Maybe a -> Bool
isNothing a =
  case a of
    Nothing -> True
    Just a -> False

cellOnBorder : Hex -> Direction -> Cells -> Maybe Hex
cellOnBorder coord side cells =
  case head cells of
    Nothing -> Nothing
    Just hd ->
      case tail cells of
        Nothing -> Nothing
        Just tl -> 
          if isBorderOnSide coord side hd then Just (hd)
          else if length cells == 1 then Nothing
          else cellOnBorder coord side tl


isBorderOnSide : Hex -> Direction -> Hex -> Bool
isBorderOnSide coord side other =
  if coord === other then False
  else 
    isBorderOnSideCube coord side other

-- offset implementation - too messy but probably faster:
isBorderOnSideCube : Hex -> Direction -> Hex -> Bool
isBorderOnSideCube coord side other =
  let
    (x, y) = HL.hexToOffset coord
    (x', y') = HL.hexToOffset other
    even = y % 2 == 0
  in
    case side of
      HH.W -> y' == y && x' == x - 1
      HH.E -> y' == y && x' == x + 1
      HH.NW -> if even then x' == x - 1 && y' == y - 1
            else x' == x && y' == y - 1
      HH.NE -> if even then x' == x && y' == y - 1
            else x' == x + 1 && y' == y - 1
      HH.SW -> if even then x' == x - 1 && y' == y + 1
            else x' == x && y' == y + 1
      HH.SE -> if even then x' == x && y' == y + 1
            else x' == x + 1 && y' == y + 1
