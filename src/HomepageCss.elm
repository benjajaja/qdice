module HomepageCss exposing (css)

import Css exposing (..)
import Css.Elements exposing (..)
import Css.Namespace exposing (namespace)
import SharedStyles exposing (..)

css : Stylesheet
css =
  (stylesheet << namespace homepageNamespace.name)
    [ body
      [ fontFamily sansSerif
      ]
    , (#) Logo
      [ 
      ]
    , header
      [ backgroundColor (rgb 90 90 90)
      , boxSizing borderBox
      , padding (px -80)
      ]
    , nav
      [ display inlineBlock
      , paddingBottom (px 12)
      ]
    , (.) NavLink
      [ margin (px 12)
      , color (rgb 255 255 255)
      ]
    , (#) BuyTickets
      [ padding (px 16)
      , paddingLeft (px 24)
      , paddingRight (px 24)
      , marginLeft (px 50)
      , marginRight auto
      , color (rgb 255 255 255)
      , backgroundColor (rgb 27 217 130)
      , verticalAlign middle
      ]
    ]

