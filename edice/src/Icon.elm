module Icon exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)


icon : String -> Html a
icon string =
    i [ class "material-icons", attribute "aria-hidden" "true" ] [ text string ]


iconSized : Int -> String -> Html a
iconSized size string =
    i [ class "material-icons", style "font-size" <| String.fromInt size ++ "px", attribute "aria-hidden" "true" ] [ text string ]


spinning : String -> Html a
spinning string =
    i [ class "material-icons material-icon-spinner", attribute "aria-hidden" "true" ] [ text string ]


spinner : Html a
spinner =
    i [ class "material-icons material-icon-spinner", attribute "aria-hidden" "true" ] [ text "wifi" ]
