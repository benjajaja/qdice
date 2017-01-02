module Tables exposing (Table(..), decodeTable)


type Table
    = Melchor
    | Cepero


decodeTable : String -> Table
decodeTable name =
    case name of
        "Melchor" ->
            Melchor

        _ ->
            Debug.crash <| "unknown table: " ++ name
