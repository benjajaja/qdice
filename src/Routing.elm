module Routing exposing (..)

import Http
import Navigation exposing (Location)
import UrlParser exposing (..)
import Types exposing (..)
import Tables exposing (Table(..), decodeTable, encodeTable)
import Backend.HttpCommands exposing (findBestTable, leaderBoard)


matchers : Parser (Route -> a) a
matchers =
    oneOf
        [ map (HomeRoute) top
        , tableMatcher
        , map StaticPageRoute (s "static" </> staticPageMatcher)
        , map EditorRoute (s "editor")
        , map MyProfileRoute (s "me")
        , map TokenRoute (s "token" </> string)
        , map ProfileRoute (s "profile" </> string)
        , map LeaderBoardRoute (s "leaderboard")
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
            HomeRoute ->
                "#"

            GameRoute table ->
                "#" ++ (encodeTable table)

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

            TokenRoute token ->
                "#token/" ++ token

            ProfileRoute id ->
                "#profile/" ++ id

            LeaderBoardRoute ->
                "#leaderboard"


routeEnterCmd : Model -> Route -> Cmd Msg
routeEnterCmd model route =
    case route of
        LeaderBoardRoute ->
            leaderBoard model.backend

        HomeRoute ->
            findBestTable model.backend

        _ ->
            Debug.log ("enter " ++ toString route) Cmd.none
