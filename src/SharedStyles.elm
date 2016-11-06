module SharedStyles exposing (..)

import Html.CssHelpers exposing (withNamespace)


type CssClasses
  = NavLink


type CssIds
  = Root
  | Logo
  | BuyTickets


homepageNamespace =
  withNamespace "homepage"