module Static.View exposing (view)

import Types exposing (..)
import Html


view : Model -> Html.Html Types.Msg
view model =
    Html.div []
        [ Html.text "HALP" ]
