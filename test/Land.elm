module Main exposing (..) -- where

import List

import ElmTest exposing (..)
import List.Nonempty as NE exposing (Nonempty, (:::))

import Land

tests : List Test
tests =
    [ 0 `equals` 0
    -- , test "isBorderOnSide" <| assert 
    -- , test "fail" <| assertNotEqual True False
    ]
    ++
    borderOnSideTest
    ++
    (List.map defaultTest <| assertionList [1..10] [1..10])

fullGrid =
  List.map (\row ->
    List.map (\col ->
      (row, col)
    ) [0..5]
  ) [0..3]
  |> List.concat

borderOnSideTest =
  List.map (\c ->
    List.map (\o ->
      List.map (\s ->
        test "isBorderOnSide" <| assert <| testTwo c s o
      ) (NE.toList Land.allSides)
    ) fullGrid
    |> List.concat
  ) fullGrid
  |> List.concat

testTwo coord side other =
  let
    _ = Debug.log "isBorderOnSide" (Land.isBorderOnSide coord side other == Land.isBorderOnSideCube coord side other
    , coord, side, other)
  in
    Land.isBorderOnSide coord side other == Land.isBorderOnSideCube coord side other

consoleTests : Test
consoleTests =
    suite "All Tests" tests

main =
    runSuite consoleTests