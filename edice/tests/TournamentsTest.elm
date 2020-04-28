module TournamentsTest exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Helpers exposing (combine)
import Test exposing (..)
import Tournaments exposing (..)


suite : Test
suite =
    describe "Tournaments"
        [ describe "Times"
            [ test "remaing seconds" <| \_ -> Expect.equal "50 seconds" <| formatSeconds 50
            , test "remaing seconds 59s" <| \_ -> Expect.equal "59 seconds" <| formatSeconds 59
            , test "remaing minute 60s" <| \_ -> Expect.equal "1 minute" <| formatSeconds 60
            , test "remaing minute 61s" <| \_ -> Expect.equal "1 minute 1 second" <| formatSeconds 61
            , test "remaing minute 100s" <| \_ -> Expect.equal "1 minute 40 seconds" <| formatSeconds 100
            , test "remaing minutes" <| \_ -> Expect.equal "2 minutes" <| formatSeconds 120
            , test "remaing minutes 150s" <| \_ -> Expect.equal "2 minutes" <| formatSeconds 150
            , test "remaing minutes 300s" <| \_ -> Expect.equal "5 minutes" <| formatSeconds 300
            , test "remaing minutes 40m" <| \_ -> Expect.equal "40 minutes" <| formatSeconds <| 60 * 40
            , test "remaing hours 60m" <| \_ -> Expect.equal "1 hour" <| formatSeconds <| 60 * 60
            , test "remaing hours 61m" <| \_ -> Expect.equal "1 hour 1 minute" <| formatSeconds <| 60 * 61
            , test "remaing hours 119m" <| \_ -> Expect.equal "1 hour 59 minutes" <| formatSeconds <| 60 * 119
            , test "remaing hours 120m" <| \_ -> Expect.equal "2 hours" <| formatSeconds <| 60 * 120
            , test "remaing hours 5h" <| \_ -> Expect.equal "5 hours" <| formatSeconds <| 60 * 60 * 5
            ]
        ]
