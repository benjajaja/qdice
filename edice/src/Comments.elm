module Comments exposing (gameComments, got, init, input, post, posted, profileComments, routeEnter, view)

import Backend.HttpCommands
import DateFormat
import Dict
import Game.PlayerCard exposing (playerPicture)
import Html exposing (Html, a, blockquote, button, div, form, span, text, textarea)
import Html.Attributes exposing (class, disabled, href, type_, value)
import Html.Events exposing (onClick, onInput)
import Routing.String exposing (routeToString)
import Tables exposing (Table)
import Time exposing (Zone)
import Types exposing (Comment, CommentKind(..), CommentList(..), CommentModel, CommentPostStatus(..), CommentsModel, GamesSubRoute(..), Model, Msg(..), Profile, Route(..), User(..))


init : CommentsModel
init =
    Dict.empty


updateComments : Model -> CommentKind -> (CommentModel -> CommentModel) -> Model
updateComments model kind fn =
    let
        comments =
            model.comments

        comments_ =
            Dict.get (Types.commentKindKey kind) comments
                |> Maybe.withDefault
                    { list = CommentListFetching
                    , postState =
                        { value = ""
                        , status = CommentPostIdle
                        }
                    }
                |> fn
    in
    { model | comments = Dict.insert (Types.commentKindKey kind) comments_ comments }


kindName : CommentKind -> String
kindName kind =
    case kind of
        UserWall _ name ->
            "player " ++ name

        GameComments id table ->
            "game #" ++ String.fromInt id ++ " of " ++ table


profileComments : Profile -> CommentKind
profileComments profile =
    UserWall profile.id profile.name


gameComments : Table -> Int -> CommentKind
gameComments table gameId =
    GameComments gameId table


routeEnter : Route -> Model -> Cmd Msg -> ( Model, Cmd Msg )
routeEnter route model cmd =
    case route of
        ProfileRoute id name ->
            fetchWith model cmd <| UserWall id name

        GamesRoute sub ->
            case sub of
                GameId table id ->
                    fetchWith model cmd <| GameComments id table

                _ ->
                    ( model, cmd )

        _ ->
            ( model, cmd )


fetchWith : Model -> Cmd Msg -> CommentKind -> ( Model, Cmd Msg )
fetchWith model cmds kind =
    let
        httpCmd =
            Backend.HttpCommands.comments model.backend kind

        comments =
            model.comments

        comments_ =
            comments
    in
    ( { model | comments = comments_ }, Cmd.batch [ cmds, httpCmd ] )


got : Model -> CommentKind -> Result String (List Comment) -> ( Model, Cmd Msg )
got model kind res =
    ( updateComments model
        kind
        (\comments ->
            { comments
                | list =
                    case res of
                        Ok list ->
                            CommentListFetched list

                        Err err ->
                            CommentListError err
            }
        )
    , Cmd.none
    )


posted : Model -> CommentKind -> Result String Comment -> ( Model, Cmd Msg )
posted model kind res =
    ( updateComments model
        kind
        (\comments ->
            let
                postState =
                    comments.postState

                postState_ =
                    { postState
                        | status =
                            case res of
                                Ok _ ->
                                    CommentPostSuccess

                                Err err ->
                                    CommentPostError err
                    }

                list =
                    case res of
                        Ok comment ->
                            case comments.list of
                                CommentListFetched list_ ->
                                    CommentListFetched <| comment :: list_

                                _ ->
                                    comments.list

                        Err _ ->
                            comments.list
            in
            { comments
                | postState = postState_
                , list = list
            }
        )
    , Cmd.none
    )


input : Model -> CommentKind -> String -> ( Model, Cmd Msg )
input model kind value =
    ( updateComments model
        kind
        (\comments ->
            let
                postState =
                    comments.postState

                postState_ =
                    { postState | value = value }
            in
            { comments | postState = postState_ }
        )
    , Cmd.none
    )


post : Model -> CommentKind -> String -> ( Model, Cmd Msg )
post model kind text =
    ( updateComments model
        kind
        (\comments ->
            let
                postState =
                    comments.postState

                postState_ =
                    { postState | status = CommentPosting }
            in
            { comments | postState = postState_ }
        )
    , Backend.HttpCommands.postComment model.backend kind text
    )


view : Zone -> User -> CommentsModel -> CommentKind -> Html Msg
view zone user comments kind =
    let
        myComments =
            Dict.get (Types.commentKindKey kind) comments

        list =
            myComments
                |> Maybe.map .list
                |> Maybe.withDefault CommentListFetching

        postState =
            myComments
                |> Maybe.map .postState
                |> Maybe.withDefault { value = "", status = CommentPostIdle }
    in
    div [ class "edComments" ] <|
        [ div [ class "edComments__header" ] [ text <| "Comments of " ++ kindName kind ]
        , div [] <|
            case list of
                CommentListFetching ->
                    [ text "Loading..." ]

                CommentListError err ->
                    [ text <| "Error: " ++ err ]

                CommentListFetched list_ ->
                    case list_ of
                        [] ->
                            [ text "No comments yet" ]

                        _ ->
                            List.map (singleComment zone) list_
        ]
            ++ (case user of
                    Logged _ ->
                        case postState.status of
                            CommentPostSuccess ->
                                [ text "Comment has been posted." ]

                            _ ->
                                [ div []
                                    [ form []
                                        [ div []
                                            [ textarea
                                                [ value postState.value, onInput <| InputComment kind ]
                                                []
                                            ]
                                        , div []
                                            ([ button
                                                ([ type_ "button"
                                                 , onClick <|
                                                    PostComment kind postState.value
                                                 ]
                                                    ++ (case postState.status of
                                                            CommentPosting ->
                                                                [ disabled True ]

                                                            _ ->
                                                                []
                                                       )
                                                )
                                                (case postState.status of
                                                    CommentPosting ->
                                                        [ text "Posting..." ]

                                                    _ ->
                                                        [ text "Post comment" ]
                                                )
                                             ]
                                                ++ (case postState.status of
                                                        CommentPostError err ->
                                                            [ text <| "Error: " ++ err ]

                                                        _ ->
                                                            []
                                                   )
                                            )
                                        ]
                                    ]
                                ]

                    _ ->
                        []
               )


singleComment : Zone -> Comment -> Html Msg
singleComment zone comment =
    div [ class "edComments__comment" ]
        [ div [ class "edComments__comment__header" ]
            [ a
                [ href <|
                    routeToString False <|
                        ProfileRoute (String.fromInt comment.author.id) comment.author.name
                , class "edComments__comment__header__author"
                ]
                [ playerPicture "small" comment.author.picture comment.author.name
                , span [] [ text <| comment.author.name ]
                ]
            , span
                [ class "edComments__comment__header__timestamp" ]
                [ text <| DateFormat.format "dddd, dd MMMM yyyy HH:mm:ss" zone <| Time.millisToPosix comment.timestamp ]
            ]
        , blockquote [ class "edComments__comment__body" ] [ text <| comment.text ]
        ]
