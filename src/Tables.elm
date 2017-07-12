module Tables exposing (Table(..), decodeTable, tableList)


type Table
    = Melchor
    | Miño


tableList : List Table
tableList =
    [ Melchor, Miño ]


decodeTable : String -> Maybe Table
decodeTable name =
    case name of
        "Melchor" ->
            Just Melchor

        "Miño" ->
            Just Miño

        _ ->
            Debug.log ("unknown table: " ++ name) Nothing


encodeTable : Table -> String
encodeTable =
    toString
