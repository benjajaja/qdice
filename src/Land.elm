module Land (..) where

import Maybe exposing (..)
import List exposing(..)
import List.Nonempty as NE exposing(..)

type alias Coord = (Int, Int)
type alias Cells = NE.Nonempty Coord
type alias Land = { hexagons: Cells}
type alias Map = NE.Nonempty Land

nonemptyList : List a -> a -> NE.Nonempty a
nonemptyList list default =
  case NE.fromList list of
    Just a -> a
    Nothing -> NE.fromElement default
  

testLand : Map
testLand =
  nonemptyList [{hexagons =
    (nonemptyList [ (0, 0), (1,0)--, (2,0), (3,0)
    -- ,     (0,1), (1,1), (2,1)
    -- ,        (1,2), (2,2), (3,2)
    -- ,            (1,3), (2,3)
    -- ,               (2,4)
    ] (0, 0))
  }] {hexagons = (NE.fromElement (0,0))}
