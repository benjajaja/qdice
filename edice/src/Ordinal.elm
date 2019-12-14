module Ordinal exposing (ordinal)


ordinal : Int -> String
ordinal number =
    String.fromInt number
        ++ (case remainderBy 10 number of
                1 ->
                    "st"

                2 ->
                    "nd"

                3 ->
                    "rd"

                _ ->
                    "th"
           )
