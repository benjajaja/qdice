module Tables exposing (Table(..), decodeTable, encodeTable, tableList)


type Table
    = Melchor
    | Miño
    | Serrano
    | Avocado
    | DeLucía


tableList : List Table
tableList =
    [ Melchor, Miño, DeLucía, Serrano, Avocado ]


decodeTable : String -> Maybe Table
decodeTable name =
    case name of
        "Melchor" ->
            Just Melchor

        "Miño" ->
            Just Miño

        "Serrano" ->
            Just Serrano

        "Avocado" ->
            Just Avocado

        "DeLucía" ->
            Just DeLucía

        _ ->
            Debug.log ("unknown table: " ++ name) Nothing


encodeTable : Table -> String
encodeTable table =
    case table of
        Melchor ->
            "Melchor"

        Miño ->
            "Miño"

        Serrano ->
            "Serrano"

        Avocado ->
            "Avocado"

        DeLucía ->
            "DeLucía"
