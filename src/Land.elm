module Land exposing (..)

import Maybe exposing (..)
import List exposing (..)
import List.Nonempty as NE exposing (Nonempty, (:::))
import Random
import Hexagons.Hex as HH exposing (Hex, Direction, (===))
import Hexagons.Layout as HL exposing (offsetToHex)

type alias Cells = NE.Nonempty Hex

type alias Land =
  { hexagons: Cells
  , color: Color
  , selected: Bool
  }

type alias Map = NE.Nonempty Land
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


nonemptyList : List a -> a -> NE.Nonempty a
nonemptyList list default =
  case NE.fromList list of
    Just a -> a
    Nothing -> NE.fromElement default


errorLand : Land
errorLand = Land (NE.fromElement <| HL.offsetToHex (0, 0)) Editor False


fullCellMap : Int -> Int -> Map
fullCellMap w h =
  case 
  List.map (\r ->
    List.map (\c ->
      { hexagons = NE.fromElement <| HL.offsetToHex (c, r)
      , color = Neutral
      , selected = False}
    ) [0..w]
  ) [0..h]
  |> List.concat
  -- |> List.filter (\l ->
  --   let head = l.hexagons |> NE.head
  --   in not (head == (1,1) || head == (1,0) || head == (0,1))
  -- )
  -- |> (::) 
  -- [{ hexagons = (1,1) ::: (1,0) ::: NE.fromElement (0,1)
  --   , color = Yellow
  --   , selected = False}]
  |> NE.fromList of
    Just a -> a
    Nothing -> NE.fromElement errorLand

offsetToHex : (Int, Int) -> Hex
offsetToHex (col, row) =
  HH.AxialHex (col - ((toFloat row) / 2 |> floor), row)

landColor : Map -> Land -> Color -> Map
landColor map land color =
  NE.map (\l -> {l | color = if land == l then color else l.color }) map

highlight : Bool -> Map -> Land -> Map
highlight highlight map land =
  -- map
  NE.map (\l ->
    if l == land then { land | selected = highlight }
    else l 
  ) map
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
filter : (Land -> Bool) -> Map -> Maybe Map
filter filter map =
  NE.toList map
  |> List.filter filter
  |> NE.fromList

append : Map -> Land -> Map
append map land =
  NE.append (NE.fromElement land) map

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
    list : List Land
    list = (NE.toList map)
    cb : Hex -> Land -> Bool
    cb hex land = NE.any (\h -> h === hex) land.hexagons
    index = indexOf list (cb hex)
  in
    index


-- concat all lands in map to a single land
concat : Map -> Land
concat map =
  let
    firstLand = NE.head map
    map' = NE.tail map |> NE.fromList
    fold land result =
      NE.append result land.hexagons
  in
    case map' of
      Nothing -> Land firstLand.hexagons Neutral False
      Just m -> 
        Land (NE.foldl fold (firstLand.hexagons) m) Neutral False


-- set one color to neutral
setNeutral : Map -> Color -> Map
setNeutral map color =
  NE.map (\l -> { l | color = (if l.color == color then Neutral else l.color) }) map


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
  NE.map (\l -> if l == land then { land | color = color } else l) map

allSides : Nonempty Direction
allSides = HH.NW ::: (HH.NE ::: (HH.E ::: (HH.SE ::: (HH.SW ::: (NE.fromElement HH.W)))))


defaultSide : Direction
defaultSide = HH.NW

  
landBorders : Cells -> Nonempty Border
landBorders cells =
  let
    (coord, side) = firstFreeBorder cells
  in
    if False && NE.length cells == 1 then
      (coord, rightSide side) ::: NE.fromElement (coord, side)
    else
      case nextBorders cells coord (coord, side) side [(coord, side)] |> NE.fromList of
        Just a -> a
        Nothing -> NE.fromElement (coord, side)


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
  NE.any (\c -> c === coord) cells

firstFreeBorder : Cells -> Border
firstFreeBorder cells =
  case hasFreeBorder cells (NE.head cells) allSides of
    Just a -> (NE.head cells, a)
    Nothing -> NE.pop cells |> firstFreeBorder


hasFreeBorder : Cells -> Hex -> Nonempty Direction -> Maybe Direction
hasFreeBorder cells coord sides =
  let side = NE.head sides
  in
    if cellOnBorder coord side cells |> isNothing then Just side
    else if NE.length sides == 1 then Just <| NE.head sides
    else hasFreeBorder cells coord <| NE.pop sides


isNothing : Maybe a -> Bool
isNothing a =
  case a of
    Nothing -> True
    Just a -> False

cellOnBorder : Hex -> Direction -> Cells -> Maybe Hex
cellOnBorder coord side cells =
  if NE.head cells |> isBorderOnSide coord side then Just (NE.head cells)
  else if NE.length cells == 1 then Nothing
  else cellOnBorder coord side <| NE.pop cells


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
