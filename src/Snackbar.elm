module Snackbar exposing (toast, toastCmd)

import Task
import Types


toast : Types.Model -> String -> ( Types.Model, Cmd Types.Msg )
toast model message =
    ( model, Cmd.none )


toastCmd : String -> Cmd Types.Msg
toastCmd message =
    Types.ErrorToast message
        |> Task.succeed
        |> Task.perform identity
