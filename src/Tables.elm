module Tables exposing (Table(..), decodeTable)


type Table
    = Melchor
    | Miño


decodeTable : String -> Maybe Table
decodeTable name =
    case name of
        "Melchor" ->
            Just Melchor

        "Miño" ->
            Just Miño

        _ ->
            Debug.log ("unknown table: " ++ name) Nothing
