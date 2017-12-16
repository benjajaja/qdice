module Snackbar exposing (Model, Msg, init, update, toast, view)

import Html exposing (..)
import Material
import Material.Helpers exposing (map1st, map2nd, delay, pure, cssTransitionStep)
import Material.Snackbar as Snackbar
import Time exposing (Time, millisecond)


init : Model
init =
    { count = 0
    , squares = []
    , snackbar = Snackbar.model
    , mdl = Material.model
    }


type alias Model =
    { count : Int
    , squares : List Square
    , snackbar : Snackbar.Model Int
    , mdl : Material.Model
    }


type Msg
    = AddSnackbar
    | AddToast
    | Appear Int
    | Grown Int
    | Gone Int
    | Snackbar (Snackbar.Msg Int)
    | Mdl (Material.Msg Msg)


type Square_
    = Appearing
    | Growing
    | Waiting
    | Active
    | Idle
    | Disappearing


type alias Square =
    ( Int, Square_ )


toast : Model -> String -> ( Model, Cmd Msg )
toast model message =
    let
        ( snackbar_, effect ) =
            Snackbar.add (Snackbar.toast 0 message) model.snackbar
                |> map2nd (Cmd.map Snackbar)

        model_ =
            { model | snackbar = snackbar_ }
    in
        model_ ! [ effect ]


view : Model -> Html Msg
view model =
    Snackbar.view model.snackbar |> Html.map Snackbar


add : (Int -> Snackbar.Contents Int) -> Model -> ( Model, Cmd Msg )
add f model =
    let
        ( snackbar_, effect ) =
            Snackbar.add (f model.count) model.snackbar
                |> map2nd (Cmd.map Snackbar)

        model_ =
            { model
                | snackbar = snackbar_
                , count = model.count + 1
                , squares = ( model.count, Appearing ) :: model.squares
            }
    in
        ( model_
        , Cmd.batch
            [ cssTransitionStep (Appear model.count)
            , effect
            ]
        )


update : Msg -> Model -> ( Model, Cmd Msg )
update action model =
    case action of
        AddSnackbar ->
            add (\k -> Snackbar.snackbar k ("Snackbar message #" ++ toString k) "UNDO") model

        AddToast ->
            add (\k -> Snackbar.toast k <| "Toast message #" ++ toString k) model

        Appear k ->
            ( model
                |> mapSquare k
                    (\sq ->
                        if sq == Appearing then
                            Growing
                        else
                            sq
                    )
            , delay transitionLength (Grown k)
            )

        Grown k ->
            model
                |> mapSquare k
                    (\sq ->
                        if sq == Growing then
                            Waiting
                        else
                            sq
                    )
                |> pure

        Snackbar (Snackbar.Begin k) ->
            model |> mapSquare k (always Active) |> pure

        Snackbar (Snackbar.End k) ->
            model
                |> mapSquare k
                    (\sq ->
                        if sq /= Disappearing then
                            Idle
                        else
                            sq
                    )
                |> pure

        Snackbar (Snackbar.Click k) ->
            ( model |> mapSquare k (always Disappearing)
            , delay transitionLength (Gone k)
            )

        Gone k ->
            ( { model
                | squares = List.filter (Tuple.first >> (/=) k) model.squares
              }
            , Cmd.none
            )

        Snackbar msg_ ->
            Snackbar.update msg_ model.snackbar
                |> map1st (\s -> { model | snackbar = s })
                |> map2nd (Cmd.map Snackbar)

        Mdl msg_ ->
            Material.update Mdl msg_ model


mapSquare : Int -> (Square_ -> Square_) -> Model -> Model
mapSquare k f model =
    { model
        | squares =
            List.map
                (\(( k_, sq ) as s) ->
                    if k /= k_ then
                        s
                    else
                        ( k_, f sq )
                )
                model.squares
    }


transitionLength : Time
transitionLength =
    150 * millisecond
