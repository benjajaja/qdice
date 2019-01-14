module Tables exposing (Table, Map(..), decodeMap)

type alias Table = String

type Map
    = Null
    | Melchor
    | Miño
    | Serrano
    | DeLucía
    | Sabicas


--tableList : List Table
--tableList =
--    [ Melchor, Miño, DeLucía, Serrano, Avocado ]


decodeMap : String -> Maybe Map
decodeMap name =
    case name of
        "Melchor" ->
            Just Melchor

        "Miño" ->
            Just Miño

        "Serrano" ->
            Just Serrano

        "DeLucía" ->
            Just DeLucía

        "Sabicas" ->
            Just Sabicas

        _ ->
            Nothing


-- encodeMap : Map -> String
-- encodeMap map =
--     case map of
--         Null ->
--             "Null"

--         Melchor ->
--             "Melchor"

--         Miño ->
--             "Miño"

--         Serrano ->
--             "Serrano"

--         Avocado ->
--             "Avocado"

--         DeLucía ->
--             "DeLucía"

--         Sabicas ->
--             "Sabicas"

