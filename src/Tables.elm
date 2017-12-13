module Tables exposing (Table(..), decodeTable, tableList)


type Table
    = Melchor
    | Miño
    | Sabicas


tableList : List Table
tableList =
    [ Melchor, Miño, Sabicas ]


decodeTable : String -> Maybe Table
decodeTable name =
    case name of
        "Melchor" ->
            Just Melchor

        "Miño" ->
            Just Miño

        "Sabicas" ->
            Just Sabicas

        _ ->
            Debug.log ("unknown table: " ++ name) Nothing


encodeTable : Table -> String
encodeTable =
    toString
