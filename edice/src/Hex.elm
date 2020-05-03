module Hex exposing (Direction(..), Hex, Point, borderLeftCorner, center, eq, hexToOffset, myLayout, offsetToHex)


type alias Point =
    ( Float, Float )


type alias Hex =
    ( Int, Int, Int )


type Direction
    = NE
    | E
    | SE
    | SW
    | W
    | NW


type alias Layout =
    { orientation : Orientation
    , size : Point
    , origin : Point
    }


{-| 2x2 matrix, by x and y coordinates
-}
type alias Square2Matrix =
    { f0 : Float
    , f1 : Float
    , f2 : Float
    , f3 : Float
    }


{-| Orientation helper type to store these: the 2×2 forward matrix, the 2×2 inverse matrix, and the starting angle
-}
type alias Orientation =
    { forward_matrix : Square2Matrix
    , inverse_matrix : Square2Matrix
    , start_angle : Float
    }


eq : Hex -> Hex -> Bool
eq ( a1, a2, a3 ) ( b1, b2, b3 ) =
    a1 == b1 && a2 == b2 && a3 == b3


myLayout : ( Float, Float ) -> Layout
myLayout size =
    { orientation = orientationLayoutPointy
    , size = size
    , origin = ( 0, 0 )
    }


{-| Contant definition of pointy hexagon orientation
-}
orientationLayoutPointy : Orientation
orientationLayoutPointy =
    { forward_matrix =
        { f0 = sqrt 3.0
        , f1 = sqrt 3.0 / 2.0
        , f2 = 0.0
        , f3 = 3.0 / 2.0
        }
    , inverse_matrix =
        { f0 = sqrt 3.0 / 3.0
        , f1 = -1.0 / 3.0
        , f2 = 0.0
        , f3 = 2.0 / 3.0
        }
    , start_angle = 0.5
    }


offsetToHex : ( Int, Int ) -> Hex
offsetToHex ( col, row ) =
    let
        x =
            col - round (toFloat (row + modBy 2 (abs row)) / 2)
    in
    -- HH.intFactory ( x, row )
    ( x, row, -x - row )


hexToOffset : Hex -> ( Int, Int )
hexToOffset ( q, r, _ ) =
    let
        offset =
            0

        col =
            q + ((r + offset * modBy 2 (abs r)) // 2)

        row =
            r
    in
    ( col, row )


{-| Left/counter-clockwise point of Hex edge
-}
borderLeftCorner : Layout -> ( Hex, Direction ) -> Point
borderLeftCorner layout ( hex, corner ) =
    let
        ( x, y ) =
            center layout hex

        ( x_, y_ ) =
            hexCornerOffset layout.size layout.orientation.start_angle corner
    in
    ( precision 2 <| x + x_, precision 2 <| y + y_ )


center : Layout -> Hex -> Point
center layout ( q, r, _ ) =
    let
        { f0, f1, f2, f3 } =
            layout.orientation.forward_matrix

        ( xl, yl ) =
            layout.size

        ( xo, yo ) =
            layout.origin

        x =
            precision 2 <| (((f0 * toFloat q) + (f1 * toFloat r)) * xl) + xo

        y =
            precision 2 <| (((f2 * toFloat q) + (f3 * toFloat r)) * yl) + yo
    in
    ( x, y )


{-| Round Float number to some division
-}
precision : Int -> Float -> Float
precision division number =
    let
        k =
            toFloat <| 10 ^ division
    in
    (toFloat << round) (number * k) / k


{-| Calculate corner offset from a center of the Hex
-}
hexCornerOffset : ( Float, Float ) -> Float -> Direction -> Point
hexCornerOffset ( w, h ) startAngle side =
    let
        angle =
            sideAngle startAngle side
    in
    ( w * cos angle, h * sin angle )


sideAngle : Float -> Direction -> Float
sideAngle startAngle side =
    ((2.0 * pi) * (toFloat (sideIndex side) + startAngle)) / 6


sideIndex : Direction -> Int
sideIndex side =
    case side of
        SW ->
            1

        W ->
            2

        NW ->
            3

        NE ->
            4

        E ->
            5

        SE ->
            6
