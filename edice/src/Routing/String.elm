module Routing.String exposing (routeToString)

import String.Normalize exposing (slug)
import Types exposing (GamesSubRoute(..), Route(..), StaticPage(..))
import Url.Builder


routeToString : Bool -> Route -> String
routeToString useHash route =
    (if useHash then
        "#"

     else
        ""
    )
        ++ (case route of
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

                ProfileRoute id name ->
                    Url.Builder.relative [ "profile", id, slug name ] []

                LeaderBoardRoute ->
                    "leaderboard"

                GamesRoute sub ->
                    "games"
                        ++ (case sub of
                                GamesOfTable table ->
                                    "/" ++ table

                                GameId table id ->
                                    "/" ++ table ++ "/" ++ String.fromInt id

                                AllGames ->
                                    ""
                           )
           )
