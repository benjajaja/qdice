module App exposing (main)

import Browser exposing (Document, UrlRequest)
import Browser.Navigation exposing (Key)
import Edice exposing (init, subscriptions, updateWrapper, view)
import Routing exposing (fragmentUrl)
import Types exposing (..)
import Url exposing (Url)


main : Program Flags Model Msg
main =
    application
        { init = init
        , view = view
        , update = updateWrapper
        , subscriptions = subscriptions
        , onUrlRequest = OnUrlRequest
        , onUrlChange = OnLocationChange
        }


application :
    { init : Flags -> Url -> Key -> ( model, Cmd msg )
    , view : model -> Document msg
    , update : msg -> model -> ( model, Cmd msg )
    , subscriptions : model -> Sub msg
    , onUrlRequest : UrlRequest -> msg
    , onUrlChange : Url -> msg
    }
    -> Program Flags model msg
application config =
    Browser.application
        { init =
            \flags url key ->
                config.init flags
                    (if flags.zip then
                        fragmentUrl url

                     else
                        url
                    )
                    key
        , view = config.view
        , update = config.update
        , subscriptions = config.subscriptions
        , onUrlRequest = config.onUrlRequest
        , onUrlChange = config.onUrlChange
        }
