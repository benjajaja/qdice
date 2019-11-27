module Routing exposing (goToBestTable, matchers, navigateTo, parseLocation, replaceNavigateTo, routeEnterCmd, routeToString, staticPageMatcher, tableMatcher)

import Backend.HttpCommands exposing (leaderBoard)
import Browser.Navigation exposing (Key)
import Http
import Tables exposing (Table)
import Types exposing (..)
import Url exposing (Url, percentDecode)
import Url.Parser exposing (..)


matchers : Parser (Route -> a) a
matchers =
    oneOf
        [ map HomeRoute top
        , map StaticPageRoute (s "static" </> staticPageMatcher)
        , map MyProfileRoute (s "me")
        , map TokenRoute (s "token" </> string)
        , map ProfileRoute (s "profile" </> string)
        , map LeaderBoardRoute (s "leaderboard")
        , tableMatcher
        ]


staticPageMatcher : Parser (StaticPage -> a) a
staticPageMatcher =
    custom "STATIC_PAGE" <|
        \segment ->
            case segment of
                "help" ->
                    Just Help

                "about" ->
                    Just About

                _ ->
                    Nothing


tableMatcher : Parser (Route -> a) a
tableMatcher =
    custom "GAME" <|
        \segment ->
            percentDecode segment |> Maybe.map GameRoute



--case Http.decodeUri segment of
--Just table ->
--Ok (GameRoute table)
--Nothing ->
--Err <| "No such table: " ++ segment
-- XXXXX


parseLocation : Url -> Route
parseLocation url =
    parse matchers url
        |> Maybe.withDefault NotFoundRoute


navigateTo : Key -> Route -> Cmd Msg
navigateTo key route =
    Browser.Navigation.pushUrl key <| routeToString route


replaceNavigateTo : Key -> Route -> Cmd Msg
replaceNavigateTo key route =
    Browser.Navigation.replaceUrl key <| routeToString route


routeToString : Route -> String
routeToString route =
    case route of
        HomeRoute ->
            ""

        GameRoute table ->
            table

        StaticPageRoute page ->
            case page of
                Help ->
                    "static/help"

                About ->
                    "static/about"

        NotFoundRoute ->
            "404"

        MyProfileRoute ->
            "me"

        TokenRoute token ->
            "token/" ++ token

        ProfileRoute id ->
            "profile/" ++ id

        LeaderBoardRoute ->
            "leaderboard"


routeEnterCmd : Model -> Route -> Cmd Msg
routeEnterCmd model route =
    case route of
        LeaderBoardRoute ->
            leaderBoard model.backend

        HomeRoute ->
            goToBestTable model

        _ ->
            Cmd.none


goToBestTable : Model -> Cmd Msg
goToBestTable model =
    case List.head <| List.filter hasSomePlayers model.tableList of
        Just bestTable ->
            replaceNavigateTo model.key <| GameRoute bestTable.table

        Nothing ->
            replaceNavigateTo model.key <| GameRoute "España"


hasSomePlayers table =
    table.playerCount > 0
