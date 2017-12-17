module Tables exposing (Table(..), decodeTable, tableList)


type Table
    = Melchor
    | Miño
    | Sabicas
    | Avocado


tableList : List Table
tableList =
    [ Melchor, Miño, Sabicas, Avocado ]


decodeTable : String -> Maybe Table
decodeTable name =
    case name of
        "Melchor" ->
            Just Melchor

        "Miño" ->
            Just Miño

        "Sabicas" ->
            Just Sabicas

        "Avocado" ->
            Just Avocado

        _ ->
            Debug.log ("unknown table: " ++ name) Nothing


encodeTable : Table -> String
encodeTable =
    toString
