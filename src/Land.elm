module Land (..) where

type alias Hexagon = (Int, Int)
type alias Land = { hexagons: List Hexagon}

testLand : List Land
testLand =
  [{hexagons =
    [ (0,0), (1,0), (2,0), (3,0)
    ,     (0,1), (1,1), (2,1)
    ,        (1,2), (2,2), (3,2)
    ,            (1,3), (2,3)
    ,               (2,4)
    ]
  }]
