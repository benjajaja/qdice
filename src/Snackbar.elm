module Snackbar exposing (toast, toastCmd)

import Task
import Types
import Helpers exposing (consoleDebug)


toast : Types.Model -> String -> String -> ( Types.Model, Cmd Types.Msg )
toast model message debug =
    ( model, toastCmd message debug )


toastCmd : String -> String -> Cmd Types.Msg
toastCmd message debug =
    Types.ErrorToast message debug
        |> Task.succeed
        |> Task.perform identity
