open! Core
open Hardcaml
open Hardcaml_waveterm

module Config = struct
  let window_size_bits = 8
  let num_windows = 2
  let affine_point_bits = 16
  let pipeline_depth = 5
  let log_stall_fifo_depth = 2
end

module Tracker = Pippenger.Track_scalars.Make (Config)
module Sim = Cyclesim.With_interface (Tracker.I) (Tracker.O)

let create_sim () =
  let sim =
    Sim.create ~config:Cyclesim.Config.trace_all (Tracker.create (Scope.create ()))
  in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in
  let waves, sim = Waveform.create sim in
  sim, inputs, outputs, waves
;;

let ( <-- ) a b = a := Bits.of_int ~width:(Bits.width !a) b

let%expect_test "unique values" =
  let sim, inputs, _, waves = create_sim () in
  let step ?(bubble = false) scalar =
    inputs.scalar <-- scalar;
    Cyclesim.cycle sim;
    inputs.shift <-- 1;
    inputs.bubble := Bits.of_bool bubble;
    Cyclesim.cycle sim;
    inputs.shift <-- 0;
    inputs.bubble <-- 0
  in
  for i = 1 to 8 do
    step i
  done;
  for _ = 0 to 6 do
    step ~bubble:true (-1)
  done;
  Waveform.print ~display_width:82 ~display_height:40 ~wave_width:0 waves;
  [%expect
    {|
    (pos 1)
    (pos 3)
    ┌Signals───────────┐┌Waves───────────────────────────────────────────────────────┐
    │clock             ││┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐│
    │                  ││ └┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└│
    │bubble            ││                                  ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─│
    │                  ││──────────────────────────────────┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ │
    │                  ││────┬───┬───┬───┬───┬───┬───┬───┬───────────────────────────│
    │scalar            ││ 01 │02 │03 │04 │05 │06 │07 │08 │FF                         │
    │                  ││────┴───┴───┴───┴───┴───┴───┴───┴───────────────────────────│
    │shift             ││  ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─│
    │                  ││──┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ │
    │is_in_pipeline    ││                                                            │
    │                  ││────────────────────────────────────────────────────────────│
    │                  ││────────────────────────┬───┬───┬───┬───┬───┬───┬───┬───┬───│
    │scalar_out        ││ 00                     │01 │02 │03 │04 │05 │06 │07 │08 │00 │
    │                  ││────────────────────────┴───┴───┴───┴───┴───┴───┴───┴───┴───│
    │                  ││────┬───┬───┬───┬───┬───┬───┬───┬───┬───────────────────────│
    │scl$0             ││ 00 │01 │02 │03 │04 │05 │06 │07 │08 │00                     │
    │                  ││────┴───┴───┴───┴───┴───┴───┴───┴───┴───────────────────────│
    │                  ││────────┬───┬───┬───┬───┬───┬───┬───┬───┬───────────────────│
    │scl$1             ││ 00     │01 │02 │03 │04 │05 │06 │07 │08 │00                 │
    │                  ││────────┴───┴───┴───┴───┴───┴───┴───┴───┴───────────────────│
    │                  ││────────────┬───┬───┬───┬───┬───┬───┬───┬───┬───────────────│
    │scl$2             ││ 00         │01 │02 │03 │04 │05 │06 │07 │08 │00             │
    │                  ││────────────┴───┴───┴───┴───┴───┴───┴───┴───┴───────────────│
    │                  ││────────────────┬───┬───┬───┬───┬───┬───┬───┬───┬───────────│
    │scl$3             ││ 00             │01 │02 │03 │04 │05 │06 │07 │08 │00         │
    │                  ││────────────────┴───┴───┴───┴───┴───┴───┴───┴───┴───────────│
    │                  ││────────────────────┬───┬───┬───┬───┬───┬───┬───┬───┬───────│
    │scl$4             ││ 00                 │01 │02 │03 │04 │05 │06 │07 │08 │00     │
    │                  ││────────────────────┴───┴───┴───┴───┴───┴───┴───┴───┴───────│
    │                  ││────────────────────────┬───┬───┬───┬───┬───┬───┬───┬───┬───│
    │scl$5             ││ 00                     │01 │02 │03 │04 │05 │06 │07 │08 │00 │
    │                  ││────────────────────────┴───┴───┴───┴───┴───┴───┴───┴───┴───│
    │                  ││                                                            │
    │                  ││                                                            │
    │                  ││                                                            │
    │                  ││                                                            │
    │                  ││                                                            │
    │                  ││                                                            │
    └──────────────────┘└────────────────────────────────────────────────────────────┘ |}]
;;

let%expect_test "same values in different windows" =
  let sim, inputs, _, waves = create_sim () in
  let step ?(bubble = false) scalar =
    inputs.scalar <-- scalar;
    Cyclesim.cycle sim;
    inputs.shift <-- 1;
    inputs.bubble := Bits.of_bool bubble;
    Cyclesim.cycle sim;
    inputs.shift <-- 0;
    inputs.bubble <-- 0
  in
  for i = 1 to 4 do
    step i;
    step i
  done;
  for _ = 0 to 6 do
    step ~bubble:true (-1)
  done;
  Waveform.print ~display_width:82 ~display_height:40 ~wave_width:0 waves;
  [%expect
    {|
    (pos 1)
    (pos 3)
    ┌Signals───────────┐┌Waves───────────────────────────────────────────────────────┐
    │clock             ││┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐│
    │                  ││ └┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└│
    │bubble            ││                                  ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─│
    │                  ││──────────────────────────────────┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ │
    │                  ││────────┬───────┬───────┬───────┬───────────────────────────│
    │scalar            ││ 01     │02     │03     │04     │FF                         │
    │                  ││────────┴───────┴───────┴───────┴───────────────────────────│
    │shift             ││  ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─│
    │                  ││──┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ │
    │is_in_pipeline    ││                                                            │
    │                  ││────────────────────────────────────────────────────────────│
    │                  ││────────────────────────┬───────┬───────┬───────┬───────┬───│
    │scalar_out        ││ 00                     │01     │02     │03     │04     │00 │
    │                  ││────────────────────────┴───────┴───────┴───────┴───────┴───│
    │                  ││────┬───────┬───────┬───────┬───────┬───────────────────────│
    │scl$0             ││ 00 │01     │02     │03     │04     │00                     │
    │                  ││────┴───────┴───────┴───────┴───────┴───────────────────────│
    │                  ││────────┬───────┬───────┬───────┬───────┬───────────────────│
    │scl$1             ││ 00     │01     │02     │03     │04     │00                 │
    │                  ││────────┴───────┴───────┴───────┴───────┴───────────────────│
    │                  ││────────────┬───────┬───────┬───────┬───────┬───────────────│
    │scl$2             ││ 00         │01     │02     │03     │04     │00             │
    │                  ││────────────┴───────┴───────┴───────┴───────┴───────────────│
    │                  ││────────────────┬───────┬───────┬───────┬───────┬───────────│
    │scl$3             ││ 00             │01     │02     │03     │04     │00         │
    │                  ││────────────────┴───────┴───────┴───────┴───────┴───────────│
    │                  ││────────────────────┬───────┬───────┬───────┬───────┬───────│
    │scl$4             ││ 00                 │01     │02     │03     │04     │00     │
    │                  ││────────────────────┴───────┴───────┴───────┴───────┴───────│
    │                  ││────────────────────────┬───────┬───────┬───────┬───────┬───│
    │scl$5             ││ 00                     │01     │02     │03     │04     │00 │
    │                  ││────────────────────────┴───────┴───────┴───────┴───────┴───│
    │                  ││                                                            │
    │                  ││                                                            │
    │                  ││                                                            │
    │                  ││                                                            │
    │                  ││                                                            │
    │                  ││                                                            │
    └──────────────────┘└────────────────────────────────────────────────────────────┘ |}]
;;

let%expect_test "stalls" =
  let sim, inputs, outputs, waves = create_sim () in
  let step ?(bubble = false) scalar =
    inputs.scalar <-- scalar;
    Cyclesim.cycle sim;
    inputs.shift <-- 1;
    (inputs.bubble := Bits.(of_bool bubble |: !(outputs.is_in_pipeline)));
    Cyclesim.cycle sim;
    inputs.shift <-- 0;
    inputs.bubble <-- 0
  in
  step 0x1;
  step 0x10;
  step 0x2;
  step 0x20;
  step 0x1;
  step 0x30;
  step 0x4;
  step 0x20;
  for _ = 0 to 6 do
    step ~bubble:true (-1)
  done;
  Waveform.print ~display_width:82 ~display_height:40 ~wave_width:0 waves;
  [%expect
    {|
    (pos 1)
    (pos 3)
    ┌Signals───────────┐┌Waves───────────────────────────────────────────────────────┐
    │clock             ││┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐│
    │                  ││ └┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└│
    │bubble            ││                  ┌─┐         ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─│
    │                  ││──────────────────┘ └─────────┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ │
    │                  ││────┬───┬───┬───┬───┬───┬───┬───┬───────────────────────────│
    │scalar            ││ 01 │10 │02 │20 │01 │30 │04 │20 │FF                         │
    │                  ││────┴───┴───┴───┴───┴───┴───┴───┴───────────────────────────│
    │shift             ││  ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─│
    │                  ││──┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ │
    │is_in_pipeline    ││                ┌───┐       ┌───┐                           │
    │                  ││────────────────┘   └───────┘   └───────────────────────────│
    │                  ││────────────────────────┬───┬───┬───┬───┬───┬───┬───┬───────│
    │scalar_out        ││ 00                     │01 │10 │02 │20 │00 │30 │04 │00     │
    │                  ││────────────────────────┴───┴───┴───┴───┴───┴───┴───┴───────│
    │                  ││────┬───┬───┬───┬───┬───┬───┬───┬───────────────────────────│
    │scl$0             ││ 00 │01 │10 │02 │20 │00 │30 │04 │00                         │
    │                  ││────┴───┴───┴───┴───┴───┴───┴───┴───────────────────────────│
    │                  ││────────┬───┬───┬───┬───┬───┬───┬───┬───────────────────────│
    │scl$1             ││ 00     │01 │10 │02 │20 │00 │30 │04 │00                     │
    │                  ││────────┴───┴───┴───┴───┴───┴───┴───┴───────────────────────│
    │                  ││────────────┬───┬───┬───┬───┬───┬───┬───┬───────────────────│
    │scl$2             ││ 00         │01 │10 │02 │20 │00 │30 │04 │00                 │
    │                  ││────────────┴───┴───┴───┴───┴───┴───┴───┴───────────────────│
    │                  ││────────────────┬───┬───┬───┬───┬───┬───┬───┬───────────────│
    │scl$3             ││ 00             │01 │10 │02 │20 │00 │30 │04 │00             │
    │                  ││────────────────┴───┴───┴───┴───┴───┴───┴───┴───────────────│
    │                  ││────────────────────┬───┬───┬───┬───┬───┬───┬───┬───────────│
    │scl$4             ││ 00                 │01 │10 │02 │20 │00 │30 │04 │00         │
    │                  ││────────────────────┴───┴───┴───┴───┴───┴───┴───┴───────────│
    │                  ││────────────────────────┬───┬───┬───┬───┬───┬───┬───┬───────│
    │scl$5             ││ 00                     │01 │10 │02 │20 │00 │30 │04 │00     │
    │                  ││────────────────────────┴───┴───┴───┴───┴───┴───┴───┴───────│
    │                  ││                                                            │
    │                  ││                                                            │
    │                  ││                                                            │
    │                  ││                                                            │
    │                  ││                                                            │
    │                  ││                                                            │
    └──────────────────┘└────────────────────────────────────────────────────────────┘ |}]
;;
