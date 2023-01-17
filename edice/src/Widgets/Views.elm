module Widgets.Views exposing (..)

import Comments
import Game.View
import Games
import Html exposing (..)
import Html.Attributes exposing (..)
import LeaderBoard.View
import MyProfile.MyProfile
import Profile
import Routing.String
import Static.View
import Types exposing (Model, Msg(..), Route(..), User(..))
import Widgets


searchingTable : List (Html msg)
searchingTable =
    [ div [] [ text "Searching for a table..." ]
    , div [] [ a [ Routing.String.linkAttr <| GameRoute "Planeta" ] [ text "Click here if this takes too long" ] ]
    ]


notFound : List (Html msg)
notFound =
    [ div [] [ text "404 page not found" ]
    , div [] [ a [ Routing.String.linkAttr <| HomeRoute ] [ text "Click here to go back to the homepage" ] ]
    ]


notLoggedIn : List (Html msg)
notLoggedIn =
    [ div [] [ text "You must be logged in to view this." ]
    , div [] [ a [ Routing.String.linkAttr <| HomeRoute ] [ text "Click here to go back to the homepage" ] ]
    ]


loadingUser : List (Html msg)
loadingUser =
    [ div [] [ text "Getting your account ready..." ]
    , div [] [ a [ Routing.String.linkAttr <| HomeRoute ] [ text "Click here to if this takes too long" ] ]
    ]


mainView : Model -> Html.Html Msg
mainView model =
    case model.route of
        HomeRoute ->
            viewWrapper
                searchingTable

        GameRoute table ->
            Game.View.view model

        StaticPageRoute page ->
            viewWrapper
                [ Static.View.view model page
                ]

        NotFoundRoute ->
            viewWrapper
                notFound

        MyProfileRoute ->
            viewWrapper <|
                case model.user of
                    Anonymous ->
                        notLoggedIn

                    Logged user ->
                        [ div [] [ text "This section is currently disabled." ]]
                        -- [ MyProfile.MyProfile.view model.myProfile user model.preferences model.sessionPreferences ]

        TokenRoute token ->
            viewWrapper
                loadingUser

        ProfileRoute id name ->
            viewWrapper
                [ Profile.view model id name ]

        LeaderBoardRoute ->
            viewWrapper
                [ LeaderBoard.View.view model ]

        GamesRoute sub ->
            viewWrapper
                [ Games.view model sub ]

        CommentsRoute ->
            viewWrapper
                [ Comments.view model.zone model.user model.comments <| Types.AllComments
                ]


viewWrapper : List (Html.Html Msg) -> Html.Html Msg
viewWrapper children =
    Html.div [ Html.Attributes.class "edMainScreen edMainScreen__static" ] <|
        [ Widgets.logoLink
        ]
            ++ children
