module Comments exposing (got, init, input, post, posted, profileComments, routeEnter, view)

import Backend.HttpCommands
import Dict
import Html exposing (Html, a, button, div, form, text, textarea)
import Html.Attributes exposing (class, disabled, href, type_, value)
import Html.Events exposing (onClick, onInput)
import Types exposing (Comment, CommentKind(..), CommentList(..), CommentModel, CommentPostStatus(..), CommentsModel, Model, Msg(..), Profile, Route(..), User(..))


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
            name


profileComments : Profile -> CommentKind
profileComments profile =
    UserWall profile.id profile.name


routeEnter : Route -> Model -> Cmd Msg -> ( Model, Cmd Msg )
routeEnter route model cmd =
    case route of
        ProfileRoute id name ->
            fetchWith model cmd <| UserWall id name

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


view : User -> CommentsModel -> CommentKind -> Html Msg
view user comments kind =
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
        [ div [] [ text <| "Comments of " ++ kindName kind ]
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
                            List.map singleComment list_
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


singleComment : Comment -> Html msg
singleComment comment =
    div []
        [ div []
            [ a [ href <| "/profile/" ++ String.fromInt comment.author.id ++ "/" ++ comment.author.name ]
                [ text <| comment.author.name ]
            ]

        -- , div [] [ text <| comment.timestamp ]
        , div [] [ text <| comment.text ]
        ]
