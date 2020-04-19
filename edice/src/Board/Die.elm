module Board.Die exposing (die, shadow)

import Svg exposing (..)
import Svg.Attributes exposing (..)


die : Svg msg
die =
    defs []
        [ g
            [ id "die"
            , transform "scale(0.055)"
            ]
            [ Svg.path
                [ stroke "black"
                , strokeWidth "4"
                , d "M 44.274701,38.931604 44.059081,18.315979 23.545011,3.0644163 3.0997027,18.315979 2.9528307,38.931604 23.613771,54.273792 Z"
                ]
                []
            , rect
                [ fill "white"
                , stroke "black"
                , strokeWidth "0.70753205"
                , width "25.320923"
                , height "25.320923"
                , x "-13.198412"
                , y "17.248964"
                , transform "matrix(0.8016383,-0.59780937,0.8016383,0.59780937,0,0)"
                ]
                []
            , Svg.path
                [ fill "#ebebeb"
                , stroke "black"
                , strokeWidth "0.57285416"
                , d "m 2.9522657,18.430618 20.5011153,15.342466 0,20.501118 L 2.9522657,38.931736 Z"
                ]
                []
            , Svg.path
                [ fill "#ebebeb"
                , stroke "black"
                , strokeWidth "0.57285416"
                , d "m 44.275301,18.430618 -20.50112,15.342466 0,20.501118 20.50112,-15.342466 z"
                ]
                []
            , ellipse
                [ fill "black"
                , cx "23.545307"
                , cy "18.201725"
                , rx "4.7748194"
                , ry "3.5811143"
                ]
                []
            , ellipse
                [ cy "42.152149"
                , cx "-8.0335274"
                , fill "black"
                , rx "2.1917808"
                , ry "2.53085"
                , transform "matrix(1,0,0.5,0.8660254,0,0)"
                ]
                []
            , ellipse
                [ fill "black"
                , cx "55.690258"
                , cy "42.094212"
                , rx "2.1917808"
                , ry "2.5308504"
                , transform "matrix(1,0,-0.5,0.8660254,0,0)"
                ]
                []
            , ellipse
                [ transform "matrix(1,0,0.5,0.8660254,0,0)"
                , ry "2.5308504"
                , rx "2.1917808"
                , fill "black"
                , cx "-8.2909203"
                , cy "32.980541"
                ]
                []
            , ellipse
                [ cy "50.764507"
                , cx "-7.6902356"
                , fill "black"
                , rx "2.1917808"
                , ry "2.5308504"
                , transform "matrix(1,0,0.5,0.8660254,0,0)"
                ]
                []
            , ellipse
                [ transform "matrix(1,0,-0.5,0.8660254,0,0)"
                , ry "2.5308504"
                , rx "2.1917808"
                , cy "31.414658"
                , cx "55.871754"
                , fill "black"
                ]
                []
            , ellipse
                [ fill "black"
                , cx "61.509121"
                , cy "43.270634"
                , rx "2.1917808"
                , ry "2.5308504"
                , transform "matrix(1,0,-0.5,0.8660254,0,0)"
                ]
                []
            , ellipse
                [ fill "black"
                , cx "49.791553"
                , cy "41.145508"
                , rx "2.1917808"
                , ry "2.5308504"
                , transform "matrix(1,0,-0.5,0.8660254,0,0)"
                ]
                []
            , ellipse
                [ transform "matrix(1,0,-0.5,0.8660254,0,0)"
                , ry "2.5308504"
                , rx "2.1917808"
                , cy "51.882996"
                , cx "55.063419"
                , fill "black"
                ]
                []
            ]
        , Svg.path
            [ id "shadow"
            , transform "scale(0.5)"
            , stroke "black"
            , fill "black"
            , strokeWidth "2"
            , strokeLinejoin "round"
            , opacity "0.3"
            , d "M 0,0 1,0 2,1 1,2 -0.4,2 -1,1 Z"
            ]
            []
        , Svg.path
            [ id "shadow-double"
            , transform "scale(0.5)"
            , stroke "black"
            , fill "black"
            , strokeWidth "2"
            , strokeLinejoin "round"
            , opacity "0.3"
            , d "M -2,-2 1,0 2,1 1,2 -0.4,2 -3,0 -3,-1 Z"
            ]
            []
        ]


shadow : Int -> Float -> Float -> Svg msg
shadow points x_ y_ =
    if points == 0 then
        Svg.g [] []

    else
        let
            x__ =
                if points > 4 then
                    x_ + 1.0

                else
                    x_ - 0.2

            y__ =
                if points > 4 then
                    y_ + 0.5

                else
                    y_ - 0.3
        in
        Svg.use
            [ x <| String.fromFloat x__
            , y <| String.fromFloat y__
            , xlinkHref <|
                if points > 4 then
                    "#shadow-double"

                else
                    "#shadow"
            ]
            []
