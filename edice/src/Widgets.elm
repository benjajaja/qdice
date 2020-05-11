module Widgets exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Routing.String
import Types exposing (Route(..))


logoLink : Html msg
logoLink =
    a
        [ class "edLogo"
        , href <| Routing.String.routeToString False <| HomeRoute
        ]
        [ img [ src "quedice.svg", width 28, height 28, class "edLogo_img" ] []
        , span [ class "edLogo__text" ] [ text "Qdice.wtf!" ]
        ]


mainWrapper : List (Html msg) -> Html msg
mainWrapper =
    main_ [ class "Main" ]
