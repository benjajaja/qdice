module Routing exposing (..)

import Navigation exposing (Location)
import UrlParser exposing (..)
import Types exposing (..)


matchers : Parser (Route -> a) a
matchers =
    oneOf
        [ map (GameRoutes GameRoute) top
          -- , map GameTableRoute (string)
          -- , tableMatcher
        , map EditorRoute (s "editor")
        ]



-- tableMatcher : Parser (Route -> a) a
-- tableMatcher =


parseLocation : Location -> Route
parseLocation location =
    let
        route =
            case (parseHash matchers location) of
                Just route ->
                    route

                Nothing ->
                    NotFoundRoute

        _ =
            Debug.log "parseLocation" ( location, route )
    in
        route


navigateTo : Route -> Cmd Msg
navigateTo route =
    Navigation.newUrl <|
        case route of
            GameRoutes sub ->
                case sub of
                    GameRoute ->
                        "/#"

                    GameTableRoute table ->
                        "/#" ++ (toString table)

            EditorRoute ->
                "/#editor"

            NotFoundRoute ->
                "/#404"
