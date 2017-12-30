module Drawer exposing (drawer)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Material.Layout as Layout
import Material.Options as Options
import Material.Icon as Icon
import Types exposing (..)
import Tables exposing (Table(..))


drawer : User -> List (Html Msg)
drawer user =
    [ case user of
        Logged user ->
            div [ class "edDrawer__login", onClick Logout ] <|
                [ div
                    [ class "edDrawer__login__avatar"
                    , style
                        [ ( "background-image", ("url(" ++ user.picture ++ ")") )
                        , ( "background-size", "cover" )
                        ]
                    ]
                    []
                , span [] [ text user.name ]
                , span [] [ Icon.i "lock" ]
                ]

        Anonymous ->
            div [ class "edDrawer__login", onClick <| ShowLogin LoginShow ] <|
                [ div
                    [ class "edDrawer__login__avatar" ]
                    []
                , span [] [ text "Sign in" ]
                , span [ onClick Logout ] [ Icon.i "lock_open" ]
                ]
    , Layout.navigation []
        (List.map
            (\( label, path ) ->
                Layout.link
                    [ Options.onClick <| DrawerNavigateTo path ]
                    [ text label ]
            )
            [ ( "Play", GameRoute Melchor )
            , ( "My profile", MyProfileRoute )
            , ( "Help", StaticPageRoute Help )
            , ( "About", StaticPageRoute About )
            , ( "Editor (experimental)", EditorRoute )
            ]
        )
    ]
