module Land exposing (..)

import Maybe exposing (..)
import Bitwise exposing (and)
import List exposing (..)
import List.Nonempty as NE exposing (Nonempty, (:::))
import Random


type Side = NW | NE | E | SE | SW | W
type alias CubeCoord = (Int, Int, Int)
type alias Coord = (Int, Int)
type alias Cells = NE.Nonempty Coord

type alias Land =
  { hexagons: Cells
  , color: Color
  , selected: Bool
  }

type alias Map = NE.Nonempty Land
type alias Border = (Coord, Side)
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
errorLand = Land (NE.fromElement (0,0)) Editor False


fullCellMap : Int -> Int -> Map
fullCellMap w h =
  case List.map (\r ->
    List.map (\c ->
      { hexagons = NE.fromElement (r, c)
      , color = Neutral
      , selected = False}
    ) [0..w]
  ) [0..h]
  |> List.concat
  |> NE.fromList of
    Just a -> a
    Nothing -> NE.fromElement errorLand
    
landColor : Map -> Land -> Color -> Map
landColor map land color =
  NE.map (\l -> {l | color = if land == l then color else l.color }) map

highlight : Bool -> Map -> Land -> Map
highlight highlight map land =
  -- map
  let
    land' = { land | selected = highlight }
  in
    case filter (\l -> l /= land) map of
      Nothing -> NE.fromElement land'
      Just a -> land' ::: a

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


-- return land and land-index in map at coord
at : Map -> Coord -> (Int, Land)
at map coord =
  (indexOf (NE.toList map) (\l -> NE.member coord l.hexagons)
  , NE.foldl (\l -> \r -> if NE.member coord l.hexagons then l else r) (NE.head map) map)


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

allSides : Nonempty Side
allSides = NW ::: NE ::: E ::: SE ::: SW ::: NE.fromElement W


defaultSide : Side
defaultSide = NW

  
landBorders : Cells -> Nonempty Border
landBorders cells =
  let
    -- _ = Debug.log "landBorders" "?"
    (coord, side) = firstFreeBorder cells
  in
    case nextBorders cells coord (coord, side) side |> NE.fromList of
      Just a -> a
      Nothing -> NE.fromElement (coord, side)


nextBorders : Cells -> Coord -> Border -> Side -> List Border
nextBorders cells coord origin side =
  let
    tco : Cells -> Coord -> Border -> Side -> List Border -> Int -> List Border
    tco cells coord origin side accum fuse =
      let
        current = (coord, side)
        nside = nextSide side
        -- _ = Debug.log "nextBorders" (coord, origin, side, List.length accum)
      in
        if fuse == 0 then
          let
            _ = Debug.log "tco exhausted" (coord, side, List.reverse accum |> List.take 8)
          in accum
        else
          case cellOnBorder coord nside cells of
            Just c -> tco cells c origin (nextSide (oppositeSide nside)) (List.append accum [current]) (fuse - 1)
            Nothing -> if fst origin == coord && snd origin == nside then (List.append accum [current])
                      else tco cells coord origin nside (List.append accum [current]) (fuse - 1)
  in
    tco cells coord origin side [(coord, side)] 1000


nextSide : Side -> Side
nextSide side =
  case side of
    NW -> NE
    NE -> E
    E -> SE
    SE -> SW
    SW -> W
    W -> NW


oppositeSide : Side -> Side
oppositeSide =
  nextSide >> nextSide >> nextSide

hasCell : Cells -> Coord -> Bool
hasCell cells coord =
  NE.any (\c -> c == coord) cells

firstFreeBorder : Cells -> Border
firstFreeBorder cells =
  case hasFreeBorder cells (NE.head cells) allSides of
    Just a -> (NE.head cells, a)
    Nothing -> NE.pop cells |> firstFreeBorder


hasFreeBorder : Cells -> Coord -> Nonempty Side -> Maybe Side
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

cellOnBorder : Coord -> Side -> Cells -> Maybe Coord
cellOnBorder coord side cells =
  if NE.head cells |> isBorderOnSide coord side then Just (NE.head cells)
  else if NE.length cells == 1 then Nothing
  else cellOnBorder coord side <| NE.pop cells


isBorderOnSide : Coord -> Side -> Coord -> Bool
isBorderOnSide coord side other =
  if coord == other then False
  else cubeNeighbour (cubeCoord coord) side == (cubeCoord other)

-- offset implementation - too messy but probably faster:
isBorderOnSideCube : Coord -> Side -> Coord -> Bool
isBorderOnSideCube coord side other =
  let
    (x, y) = coord
    (x', y') = other
    even = y % 2 == 0
  in
    case side of
      W -> y' == y && x' == x - 1
      E -> y' == y && x' == x + 1
      NW -> if even then x' == x - 1 && y' == y - 1
            else x' == x && y' == y - 1
      NE -> if even then x' == x && y' == y - 1
            else x' == x + 1 && y' == y - 1
      SW -> if even then x' == x - 1 && y' == y + 1
            else x' == x && y' == y + 1
      SE -> if even then x' == x && y' == y + 1
            else x' == x + 1 && y' == y + 1

cubeCoord : Coord -> CubeCoord
cubeCoord coord =
  let
    (col, row) = coord
    x = (and row 1 |> (-) row |> toFloat) / 2 |> (-) (toFloat col) |> round
    z = row
    y = -(toFloat x) - (toFloat z) |> round
  in
    (x, y, z)

cubeDirection : Side -> CubeCoord
cubeDirection side =
  case side of
    NW -> (0, 1, -1)
    NE -> (1, 0, -1)
    E  -> (1, -1, 0)
    SE -> (0, -1, 1)
    SW -> (-1, 0, 1)
    W  -> (-1, 1, 0)

cubeNeighbour : CubeCoord -> Side -> CubeCoord
cubeNeighbour coord side =
  let
    (x, y, z) = coord
    (x', y', z') = cubeDirection side
  in
    (x + x', y + y', z + z')
