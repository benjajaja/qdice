module Routing exposing (..)

import Http
import Navigation exposing (Location)
import UrlParser exposing (..)
import Types exposing (..)
import Tables exposing (Table(..), decodeTable)


matchers : Parser (Route -> a) a
matchers =
    oneOf
        [ map (GameRoute Melchor) top
        , tableMatcher
        , map StaticPageRoute (s "static" </> staticPageMatcher)
        , map EditorRoute (s "editor")
        , map MyProfileRoute (s "me")
        ]


staticPageMatcher : Parser (StaticPage -> a) a
staticPageMatcher =
    UrlParser.custom "STATIC_PAGE" <|
        \segment ->
            case segment of
                "help" ->
                    Ok Help

                "about" ->
                    Ok About

                _ ->
                    Err segment


tableMatcher : Parser (Route -> a) a
tableMatcher =
    UrlParser.custom "GAME" <|
        \segment ->
            case Http.decodeUri segment of
                Just decoded ->
                    case decodeTable decoded of
                        Just table ->
                            Ok (GameRoute table)

                        Nothing ->
                            Err <| "No such table: " ++ decoded

                Nothing ->
                    Err <| "No such table: " ++ segment


parseLocation : Location -> Route
parseLocation location =
    case parseHash matchers location of
        Just route ->
            route

        Nothing ->
            NotFoundRoute


navigateTo : Route -> Cmd Msg
navigateTo route =
    Navigation.newUrl <|
        case route of
            GameRoute table ->
                "#" ++ (toString table)

            StaticPageRoute page ->
                case page of
                    Help ->
                        "#static/help"

                    About ->
                        "#static/about"

            EditorRoute ->
                "#editor"

            NotFoundRoute ->
                "#404"

            MyProfileRoute ->
                "#me"
