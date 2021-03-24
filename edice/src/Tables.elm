module Tables exposing (MapName(..), Table, decodeMap, encodeMap, isTournament)


type alias Table =
    String


type MapName
    = Null
    | Serrano
    | DeLucía
    | Sabicas
    | Planeta
    | Montoya
    | Cepero


decodeMap : String -> Result String MapName
decodeMap name =
    case name of
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

        "Cepero" ->
            Ok Cepero

        _ ->
            Err <| "Table (map) not found: " ++ name


encodeMap : MapName -> String
encodeMap map =
    case map of
        Null ->
            "Null"

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

        Cepero ->
            "Cepero"


isTournament : Table -> Bool
isTournament table =
    case table of
        "Hourly2000" ->
            True

        "5MinuteFix" ->
            True

        "MinuteMade" ->
            True

        "Daily10k" ->
            True

        _ ->
            False
