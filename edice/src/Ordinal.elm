module Ordinal exposing (ordinal)


ordinal : Int -> String
ordinal number =
    String.fromInt number
        ++ (case remainderBy 10 number of
                1 ->
                    if number == 11 then
                        "th"

                    else
                        "st"

                2 ->
                    if number == 12 then
                        "th"

                    else
                        "nd"

                3 ->
                    if number == 13 then
                        "th"

                    else
                        "rd"

                _ ->
                    "th"
           )
