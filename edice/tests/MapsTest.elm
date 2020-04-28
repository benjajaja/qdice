module MapsTest exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Helpers exposing (combine, resultCombine)
import Land
import Maps
import Tables exposing (Map(..))
import Test exposing (..)


suite : Test
suite =
    describe "Maps"
        [ describe "Maps.load"
            [ test "loads Planeta" <|
                \_ ->
                    case Maps.load Planeta of
                        Err err ->
                            Expect.fail err

                        Ok map ->
                            Expect.equal 42 <| List.length map.lands
            ]
        , describe "Land.isBordering"
            [ test "adjacency" <|
                \_ ->
                    Expect.equal
                        ([ ( "🍏", "🌙" ), ( "\u{1F920}", "👑" ) ]
                            |> List.map
                                (\( a, b ) ->
                                    case Maps.load Planeta of
                                        Err _ ->
                                            Nothing

                                        Ok map ->
                                            Maybe.map2
                                                (Land.isBordering map)
                                                (Land.findLand a map.lands)
                                                (Land.findLand b map.lands)
                                )
                            |> combine
                            |> Maybe.andThen
                                (resultCombine
                                    >> Result.toMaybe
                                )
                            |> Maybe.map (List.all identity)
                        )
                        (Just True)
            ]
        ]
