module Snackbar.Types exposing (Model, Msg(..), Square_(..), Square)

import Material
import Material.Snackbar as Snackbar


type Square_
    = Appearing
    | Growing
    | Waiting
    | Active
    | Idle
    | Disappearing


type alias Square =
    ( Int, Square_ )


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
