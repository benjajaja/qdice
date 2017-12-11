port module Helpers exposing (..)


port consoleDebug : String -> Cmd msg


{-| indexOf helper
-}
indexOf : List a -> (a -> Bool) -> Int
indexOf lst f =
    let
        helper : List a -> (a -> Bool) -> Int -> Int
        helper lst f offset =
            case lst of
                [] ->
                    -1

                x :: xs ->
                    if f x then
                        offset
                    else
                        helper xs f (offset + 1)
    in
        helper lst f 0
