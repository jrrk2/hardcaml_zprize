open Core

(* Thinking out aloud.

We are now aiming for memory bandwidth optimisation on reads and writes.

The biggest thing we can current do, is try to burst as much as possible from host memory.

We are contrained by needing to read/write in both linear and transposed orders (there
is a transposer component included in the hardware design)

We also have 8 seperate memory ports to the individual NTT rams.

The steps are:

1.  Given data layed out in linear order.
2.  READ into NTT in transposed order.
3.  WRITE from NTT in linear order
4.  READ into NTT in transposed order
5.  WRITE from NTT in transposed order

(note; linear/transposed orders in steps 3 and 4 can be swapped.)

Lets consider each in turn.Arith_status

READ transposed
===============

Read 8 coefs, write directly into the cores, stride += n

With more cores, we can read 64 coefs, write directly, stride += n

WRITE transpsosed
=================

Write 8 coefs (1 from each core), stride += n

Similar story as read for more cores

(is this actually right?)

READ linear
===========

Read into transposer component.  Same access pattern as read transposed.

WRITE linear
============

Not actually used ... 

Needs the transposer, just like read linear.

*)

let read_words ~log_cores inputs ~row ~col =
  Array.init (1 lsl log_cores) ~f:(fun c -> inputs.(row).(col + c))
;;

let read_block ~log_cores ~log_blocks ~block_row ~block_col (inputs : 'a array array) =
  let log_total = log_blocks + log_cores in
  for row = 0 to (1 lsl log_total) - 1 do
    for col = 0 to (1 lsl log_blocks) - 1 do
      let x =
        read_words
          ~log_cores
          inputs
          ~row:((block_row lsl log_total) + row)
          ~col:((block_col lsl log_total) + (col lsl log_cores))
      in
      print_s [%message "" ~_:(x : int array)]
    done
  done
;;

let read_transposed ~log_cores ~log_blocks (inputs : 'a array array) =
  let n = Array.length inputs in
  let log_total = log_cores + log_blocks in
  for block_col = 0 to (n lsr log_total) - 1 do
    for block_row = 0 to (n lsr log_total) - 1 do
      read_block ~log_cores ~log_blocks ~block_row ~block_col inputs
    done
  done
;;

let read_linear ~log_cores ~log_blocks (inputs : 'a array array) =
  let n = Array.length inputs in
  let log_total = log_cores + log_blocks in
  for block_row = 0 to (n lsr log_total) - 1 do
    for block_col = 0 to (n lsr log_total) - 1 do
      read_block ~log_cores ~log_blocks ~block_row ~block_col inputs
    done
  done
;;

let create_inputs n =
  Array.init n ~f:(fun row -> Array.init n ~f:(fun col -> (row * n) + col))
;;

let read_both ~log_cores ~log_blocks inputs =
  print_s [%message (inputs : int array array)];
  print_s [%message "transposed"];
  read_transposed ~log_cores ~log_blocks inputs;
  print_s [%message "linear"];
  read_linear ~log_cores ~log_blocks inputs
;;

let%expect_test "2 word transfers within 4x4" =
  read_both ~log_cores:1 ~log_blocks:0 (create_inputs 4);
  [%expect
    {|
    (inputs ((0 1 2 3) (4 5 6 7) (8 9 10 11) (12 13 14 15)))
    transposed
    (0 1)
    (4 5)
    (8 9)
    (12 13)
    (2 3)
    (6 7)
    (10 11)
    (14 15)
    linear
    (0 1)
    (4 5)
    (2 3)
    (6 7)
    (8 9)
    (12 13)
    (10 11)
    (14 15) |}];
  read_both ~log_cores:1 ~log_blocks:1 (create_inputs 4);
  [%expect
    {|
    (inputs ((0 1 2 3) (4 5 6 7) (8 9 10 11) (12 13 14 15)))
    transposed
    (0 1)
    (2 3)
    (4 5)
    (6 7)
    (8 9)
    (10 11)
    (12 13)
    (14 15)
    linear
    (0 1)
    (2 3)
    (4 5)
    (6 7)
    (8 9)
    (10 11)
    (12 13)
    (14 15) |}]
;;

let%expect_test "2 word transfers within 8x8" =
  read_both ~log_cores:1 ~log_blocks:0 (create_inputs 8);
  [%expect
    {|
    (inputs
     ((0 1 2 3 4 5 6 7) (8 9 10 11 12 13 14 15) (16 17 18 19 20 21 22 23)
      (24 25 26 27 28 29 30 31) (32 33 34 35 36 37 38 39)
      (40 41 42 43 44 45 46 47) (48 49 50 51 52 53 54 55)
      (56 57 58 59 60 61 62 63)))
    transposed
    (0 1)
    (8 9)
    (16 17)
    (24 25)
    (32 33)
    (40 41)
    (48 49)
    (56 57)
    (2 3)
    (10 11)
    (18 19)
    (26 27)
    (34 35)
    (42 43)
    (50 51)
    (58 59)
    (4 5)
    (12 13)
    (20 21)
    (28 29)
    (36 37)
    (44 45)
    (52 53)
    (60 61)
    (6 7)
    (14 15)
    (22 23)
    (30 31)
    (38 39)
    (46 47)
    (54 55)
    (62 63)
    linear
    (0 1)
    (8 9)
    (2 3)
    (10 11)
    (4 5)
    (12 13)
    (6 7)
    (14 15)
    (16 17)
    (24 25)
    (18 19)
    (26 27)
    (20 21)
    (28 29)
    (22 23)
    (30 31)
    (32 33)
    (40 41)
    (34 35)
    (42 43)
    (36 37)
    (44 45)
    (38 39)
    (46 47)
    (48 49)
    (56 57)
    (50 51)
    (58 59)
    (52 53)
    (60 61)
    (54 55)
    (62 63) |}];
  read_both ~log_cores:1 ~log_blocks:1 (create_inputs 8);
  [%expect
    {|
    (inputs
     ((0 1 2 3 4 5 6 7) (8 9 10 11 12 13 14 15) (16 17 18 19 20 21 22 23)
      (24 25 26 27 28 29 30 31) (32 33 34 35 36 37 38 39)
      (40 41 42 43 44 45 46 47) (48 49 50 51 52 53 54 55)
      (56 57 58 59 60 61 62 63)))
    transposed
    (0 1)
    (2 3)
    (8 9)
    (10 11)
    (16 17)
    (18 19)
    (24 25)
    (26 27)
    (32 33)
    (34 35)
    (40 41)
    (42 43)
    (48 49)
    (50 51)
    (56 57)
    (58 59)
    (4 5)
    (6 7)
    (12 13)
    (14 15)
    (20 21)
    (22 23)
    (28 29)
    (30 31)
    (36 37)
    (38 39)
    (44 45)
    (46 47)
    (52 53)
    (54 55)
    (60 61)
    (62 63)
    linear
    (0 1)
    (2 3)
    (8 9)
    (10 11)
    (16 17)
    (18 19)
    (24 25)
    (26 27)
    (4 5)
    (6 7)
    (12 13)
    (14 15)
    (20 21)
    (22 23)
    (28 29)
    (30 31)
    (32 33)
    (34 35)
    (40 41)
    (42 43)
    (48 49)
    (50 51)
    (56 57)
    (58 59)
    (36 37)
    (38 39)
    (44 45)
    (46 47)
    (52 53)
    (54 55)
    (60 61)
    (62 63) |}];
  read_both ~log_cores:1 ~log_blocks:2 (create_inputs 8);
  [%expect
    {|
    (inputs
     ((0 1 2 3 4 5 6 7) (8 9 10 11 12 13 14 15) (16 17 18 19 20 21 22 23)
      (24 25 26 27 28 29 30 31) (32 33 34 35 36 37 38 39)
      (40 41 42 43 44 45 46 47) (48 49 50 51 52 53 54 55)
      (56 57 58 59 60 61 62 63)))
    transposed
    (0 1)
    (2 3)
    (4 5)
    (6 7)
    (8 9)
    (10 11)
    (12 13)
    (14 15)
    (16 17)
    (18 19)
    (20 21)
    (22 23)
    (24 25)
    (26 27)
    (28 29)
    (30 31)
    (32 33)
    (34 35)
    (36 37)
    (38 39)
    (40 41)
    (42 43)
    (44 45)
    (46 47)
    (48 49)
    (50 51)
    (52 53)
    (54 55)
    (56 57)
    (58 59)
    (60 61)
    (62 63)
    linear
    (0 1)
    (2 3)
    (4 5)
    (6 7)
    (8 9)
    (10 11)
    (12 13)
    (14 15)
    (16 17)
    (18 19)
    (20 21)
    (22 23)
    (24 25)
    (26 27)
    (28 29)
    (30 31)
    (32 33)
    (34 35)
    (36 37)
    (38 39)
    (40 41)
    (42 43)
    (44 45)
    (46 47)
    (48 49)
    (50 51)
    (52 53)
    (54 55)
    (56 57)
    (58 59)
    (60 61)
    (62 63) |}]
;;

let%expect_test "8 word transfers within 16x16" =
  read_both ~log_cores:3 ~log_blocks:0 (create_inputs 16);
  [%expect
    {|
    (inputs
     ((0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15)
      (16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31)
      (32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47)
      (48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63)
      (64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79)
      (80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95)
      (96 97 98 99 100 101 102 103 104 105 106 107 108 109 110 111)
      (112 113 114 115 116 117 118 119 120 121 122 123 124 125 126 127)
      (128 129 130 131 132 133 134 135 136 137 138 139 140 141 142 143)
      (144 145 146 147 148 149 150 151 152 153 154 155 156 157 158 159)
      (160 161 162 163 164 165 166 167 168 169 170 171 172 173 174 175)
      (176 177 178 179 180 181 182 183 184 185 186 187 188 189 190 191)
      (192 193 194 195 196 197 198 199 200 201 202 203 204 205 206 207)
      (208 209 210 211 212 213 214 215 216 217 218 219 220 221 222 223)
      (224 225 226 227 228 229 230 231 232 233 234 235 236 237 238 239)
      (240 241 242 243 244 245 246 247 248 249 250 251 252 253 254 255)))
    transposed
    (0 1 2 3 4 5 6 7)
    (16 17 18 19 20 21 22 23)
    (32 33 34 35 36 37 38 39)
    (48 49 50 51 52 53 54 55)
    (64 65 66 67 68 69 70 71)
    (80 81 82 83 84 85 86 87)
    (96 97 98 99 100 101 102 103)
    (112 113 114 115 116 117 118 119)
    (128 129 130 131 132 133 134 135)
    (144 145 146 147 148 149 150 151)
    (160 161 162 163 164 165 166 167)
    (176 177 178 179 180 181 182 183)
    (192 193 194 195 196 197 198 199)
    (208 209 210 211 212 213 214 215)
    (224 225 226 227 228 229 230 231)
    (240 241 242 243 244 245 246 247)
    (8 9 10 11 12 13 14 15)
    (24 25 26 27 28 29 30 31)
    (40 41 42 43 44 45 46 47)
    (56 57 58 59 60 61 62 63)
    (72 73 74 75 76 77 78 79)
    (88 89 90 91 92 93 94 95)
    (104 105 106 107 108 109 110 111)
    (120 121 122 123 124 125 126 127)
    (136 137 138 139 140 141 142 143)
    (152 153 154 155 156 157 158 159)
    (168 169 170 171 172 173 174 175)
    (184 185 186 187 188 189 190 191)
    (200 201 202 203 204 205 206 207)
    (216 217 218 219 220 221 222 223)
    (232 233 234 235 236 237 238 239)
    (248 249 250 251 252 253 254 255)
    linear
    (0 1 2 3 4 5 6 7)
    (16 17 18 19 20 21 22 23)
    (32 33 34 35 36 37 38 39)
    (48 49 50 51 52 53 54 55)
    (64 65 66 67 68 69 70 71)
    (80 81 82 83 84 85 86 87)
    (96 97 98 99 100 101 102 103)
    (112 113 114 115 116 117 118 119)
    (8 9 10 11 12 13 14 15)
    (24 25 26 27 28 29 30 31)
    (40 41 42 43 44 45 46 47)
    (56 57 58 59 60 61 62 63)
    (72 73 74 75 76 77 78 79)
    (88 89 90 91 92 93 94 95)
    (104 105 106 107 108 109 110 111)
    (120 121 122 123 124 125 126 127)
    (128 129 130 131 132 133 134 135)
    (144 145 146 147 148 149 150 151)
    (160 161 162 163 164 165 166 167)
    (176 177 178 179 180 181 182 183)
    (192 193 194 195 196 197 198 199)
    (208 209 210 211 212 213 214 215)
    (224 225 226 227 228 229 230 231)
    (240 241 242 243 244 245 246 247)
    (136 137 138 139 140 141 142 143)
    (152 153 154 155 156 157 158 159)
    (168 169 170 171 172 173 174 175)
    (184 185 186 187 188 189 190 191)
    (200 201 202 203 204 205 206 207)
    (216 217 218 219 220 221 222 223)
    (232 233 234 235 236 237 238 239)
    (248 249 250 251 252 253 254 255) |}];
  read_both ~log_cores:3 ~log_blocks:1 (create_inputs 16);
  [%expect
    {|
    (inputs
     ((0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15)
      (16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31)
      (32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47)
      (48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63)
      (64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79)
      (80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95)
      (96 97 98 99 100 101 102 103 104 105 106 107 108 109 110 111)
      (112 113 114 115 116 117 118 119 120 121 122 123 124 125 126 127)
      (128 129 130 131 132 133 134 135 136 137 138 139 140 141 142 143)
      (144 145 146 147 148 149 150 151 152 153 154 155 156 157 158 159)
      (160 161 162 163 164 165 166 167 168 169 170 171 172 173 174 175)
      (176 177 178 179 180 181 182 183 184 185 186 187 188 189 190 191)
      (192 193 194 195 196 197 198 199 200 201 202 203 204 205 206 207)
      (208 209 210 211 212 213 214 215 216 217 218 219 220 221 222 223)
      (224 225 226 227 228 229 230 231 232 233 234 235 236 237 238 239)
      (240 241 242 243 244 245 246 247 248 249 250 251 252 253 254 255)))
    transposed
    (0 1 2 3 4 5 6 7)
    (8 9 10 11 12 13 14 15)
    (16 17 18 19 20 21 22 23)
    (24 25 26 27 28 29 30 31)
    (32 33 34 35 36 37 38 39)
    (40 41 42 43 44 45 46 47)
    (48 49 50 51 52 53 54 55)
    (56 57 58 59 60 61 62 63)
    (64 65 66 67 68 69 70 71)
    (72 73 74 75 76 77 78 79)
    (80 81 82 83 84 85 86 87)
    (88 89 90 91 92 93 94 95)
    (96 97 98 99 100 101 102 103)
    (104 105 106 107 108 109 110 111)
    (112 113 114 115 116 117 118 119)
    (120 121 122 123 124 125 126 127)
    (128 129 130 131 132 133 134 135)
    (136 137 138 139 140 141 142 143)
    (144 145 146 147 148 149 150 151)
    (152 153 154 155 156 157 158 159)
    (160 161 162 163 164 165 166 167)
    (168 169 170 171 172 173 174 175)
    (176 177 178 179 180 181 182 183)
    (184 185 186 187 188 189 190 191)
    (192 193 194 195 196 197 198 199)
    (200 201 202 203 204 205 206 207)
    (208 209 210 211 212 213 214 215)
    (216 217 218 219 220 221 222 223)
    (224 225 226 227 228 229 230 231)
    (232 233 234 235 236 237 238 239)
    (240 241 242 243 244 245 246 247)
    (248 249 250 251 252 253 254 255)
    linear
    (0 1 2 3 4 5 6 7)
    (8 9 10 11 12 13 14 15)
    (16 17 18 19 20 21 22 23)
    (24 25 26 27 28 29 30 31)
    (32 33 34 35 36 37 38 39)
    (40 41 42 43 44 45 46 47)
    (48 49 50 51 52 53 54 55)
    (56 57 58 59 60 61 62 63)
    (64 65 66 67 68 69 70 71)
    (72 73 74 75 76 77 78 79)
    (80 81 82 83 84 85 86 87)
    (88 89 90 91 92 93 94 95)
    (96 97 98 99 100 101 102 103)
    (104 105 106 107 108 109 110 111)
    (112 113 114 115 116 117 118 119)
    (120 121 122 123 124 125 126 127)
    (128 129 130 131 132 133 134 135)
    (136 137 138 139 140 141 142 143)
    (144 145 146 147 148 149 150 151)
    (152 153 154 155 156 157 158 159)
    (160 161 162 163 164 165 166 167)
    (168 169 170 171 172 173 174 175)
    (176 177 178 179 180 181 182 183)
    (184 185 186 187 188 189 190 191)
    (192 193 194 195 196 197 198 199)
    (200 201 202 203 204 205 206 207)
    (208 209 210 211 212 213 214 215)
    (216 217 218 219 220 221 222 223)
    (224 225 226 227 228 229 230 231)
    (232 233 234 235 236 237 238 239)
    (240 241 242 243 244 245 246 247)
    (248 249 250 251 252 253 254 255) |}]
;;