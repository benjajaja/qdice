module Tournaments exposing (..)

import DateFormat
import Time exposing (Posix, Zone, millisToPosix, posixToMillis)


tournamentTime : Zone -> Posix -> Int -> String
tournamentTime zone time timestamp =
    let
        nowSeconds =
            (toFloat <| posixToMillis time)
                / 1000
                |> round

        remainingSeconds =
            timestamp - nowSeconds

        timePosix =
            secondsToPosix timestamp
    in
    DateFormat.format
        (remainingSecondsFormat remainingSeconds)
        zone
        timePosix
        ++ " ("
        ++ formatSeconds remainingSeconds
        ++ ")"


secondsToPosix : Int -> Posix
secondsToPosix seconds =
    seconds * 1000 |> millisToPosix


formatSeconds : Int -> String
formatSeconds seconds =
    if seconds < 60 then
        String.fromInt seconds ++ " seconds"

    else if seconds < 120 then
        case seconds - 60 of
            0 ->
                "1 minute"

            1 ->
                "1 minute 1 second"

            n ->
                "1 minute " ++ String.fromInt n ++ " seconds"

    else if seconds < 3600 then
        String.fromInt (roundDiv seconds 60) ++ " minutes"

    else if seconds < 3600 * 2 then
        case roundDiv (seconds - 3600) 60 of
            0 ->
                "1 hour"

            1 ->
                "1 hour 1 minute"

            n ->
                "1 hour " ++ String.fromInt n ++ " minutes"

    else if seconds < 3600 * 24 then
        String.fromInt (roundDiv seconds 3600) ++ " hours"

    else
        String.fromInt seconds ++ " seconds"


remainingSecondsFormat : Int -> String
remainingSecondsFormat seconds =
    if seconds < 3600 * 24 then
        "HH:mm"

    else
        "dddd, dd MMMM yyyy HH:mm:ss"


roundDiv : Int -> Int -> Int
roundDiv a b =
    toFloat a / toFloat b |> floor
