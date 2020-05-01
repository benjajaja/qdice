module Tables exposing (Map(..), Table, decodeMap, encodeMap, isTournament)


type alias Table =
    String


type Map
    = Null
    | Melchor
    | Miño
    | Serrano
    | DeLucía
    | Sabicas
    | Planeta
    | Montoya


decodeMap : String -> Result String Map
decodeMap name =
    case name of
        "Melchor" ->
            Ok Melchor

        "Miño" ->
            Ok Miño

        "Serrano" ->
            Ok Serrano

        "DeLucía" ->
            Ok DeLucía

        "Sabicas" ->
            Ok Sabicas

        "Planeta" ->
            Ok Planeta

        "Montoya" ->
            Ok Montoya

        _ ->
            Err <| "Table (map) not found: " ++ name


encodeMap : Map -> String
encodeMap map =
    case map of
        Null ->
            "Null"

        Melchor ->
            "Melchor"

        Miño ->
            "Miño"

        Serrano ->
            "Serrano"

        Planeta ->
            "Planeta"

        DeLucía ->
            "DeLucía"

        Sabicas ->
            "Sabicas"

        Montoya ->
            "Montoya"


isTournament : Table -> Bool
isTournament table =
    case table of
        "Hourly2000" ->
            True

        "5MinuteFix" ->
            True

        "Daily10k" ->
            True

        _ ->
            False
