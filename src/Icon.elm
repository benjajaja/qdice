module Icon exposing (icon)

import Html exposing (..)
import Html.Attributes exposing (..)


icon : String -> Html a
icon string =
    i [ class "material-icons", attribute "aria-hidden" "true" ] [ text string ]
