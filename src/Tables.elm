module Tables exposing (Table(..), decodeTable)


type Table
    = Melchor
    | Cepero


decodeTable : String -> Maybe Table
decodeTable name =
    case name of
        "Melchor" ->
            Just Melchor

        _ ->
            Debug.log ("unknown table: " ++ name) Nothing
