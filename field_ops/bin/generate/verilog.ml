open Core
open Hardcaml
open Field_ops_lib

module Karatsuba_ofman_mult377 = Karatsuba_ofman_mult.With_interface (struct
  let bits = 377
end)

module Montgometry_mult377 = Montgomery_mult.With_interface (struct
  let bits = 377
end)

module Barrett_mult377 = Barrett_mult.With_interface (struct
  let bits = 377
end)

module Barrett_reduction377 = Barrett_reduction.With_interface (struct
  let bits = 377
end)

module Multiply_43x43 = struct
  module I = struct
    type 'a t =
      { clock : 'a
      ; x : 'a [@bits 43]
      ; y : 'a [@bits 43]
      }
    [@@deriving sexp_of, hardcaml]
  end

  module O = struct
    type 'a t = { z : 'a [@bits 86] } [@@deriving sexp_of, hardcaml]
  end
end

let flag_filename =
  Command.Param.(
    flag
      "output-filename"
      (optional_with_default "/dev/stdout" string)
      ~doc:" Output filename (Defaults to stdout)")
;;

let flag_ground_multiplier =
  let%map_open.Command multiplier_latency =
    flag
      "multiplier-latency"
      (optional_with_default 1 int)
      ~doc:" Latency of ground multipliers"
  and use_vanila_multiply =
    flag
      "use-vanila-multiply"
      no_arg
      ~doc:" Use vanila verilog multplication, rather than optimized hybrid"
  in
  if use_vanila_multiply
  then Ground_multiplier.Config.Verilog_multiply { latency = multiplier_latency }
  else Ground_multiplier.Config.Hybrid_dsp_and_luts { latency = multiplier_latency }
;;

let flag_depth =
  let open Command.Param in
  flag "depth" (optional_with_default 4 int) ~doc:" Depth karatsuba ofman splitting"
;;

let flag_multiplier_config =
  let%map_open.Command depth = flag_depth
  and ground_multiplier = flag_ground_multiplier in
  let full =
    Karatsuba_ofman_mult.Config.generate
      ~ground_multiplier
      (List.init depth ~f:(Fn.const Radix.Radix_2))
  in
  let half =
    { Half_width_multiplier.Config.level_radices =
        List.init depth ~f:(Fn.const Radix.Radix_2)
    ; ground_multiplier
    }
  in
  half, full
;;

let command_specialized_43x43_multiplier =
  Command.basic
    ~summary:"specialized 43x43 bit multiplier"
    (let%map_open.Command filename = flag_filename in
     fun () ->
       let open Multiply_43x43 in
       let create { I.clock; x; y } =
         { O.z =
             Ground_multiplier.create
               ~clock
               ~enable:Signal.vdd
               ~config:Specialized_43_bit_multiply
               x
               y
         }
       in
       let scope = Scope.create () in
       let module C = Circuit.With_interface (I) (O) in
       let database = Scope.circuit_database scope in
       let circuit = C.create_exn ~name:"specialized_43x43_multiplier" create in
       Rtl.output ~database ~output_mode:(To_file filename) Verilog circuit)
;;

let command_verilog_43x43_multiplier =
  Command.basic
    ~summary:"Verilog 43x43 bit multiplier"
    (let%map_open.Command filename = flag_filename
     and latency = flag "latency" (required int) ~doc:"" in
     fun () ->
       let open Multiply_43x43 in
       let create { I.clock; x; y } =
         { O.z =
             Ground_multiplier.create
               ~clock
               ~enable:Signal.vdd
               ~config:(Verilog_multiply { latency })
               x
               y
         }
       in
       let scope = Scope.create () in
       let module C = Circuit.With_interface (I) (O) in
       let database = Scope.circuit_database scope in
       let circuit = C.create_exn ~name:"verilog_43x43_multiplier" create in
       Rtl.output ~database ~output_mode:(To_file filename) Verilog circuit)
;;

let command_karatsuba_ofman_mult =
  Command.basic
    ~summary:"karatsuba-ofman-mult"
    (let%map_open.Command _, config = flag_multiplier_config
     and filename = flag_filename in
     fun () ->
       let module K = Karatsuba_ofman_mult377 in
       let module C = Circuit.With_interface (K.I) (K.O) in
       let scope = Scope.create () in
       let database = Scope.circuit_database scope in
       let circuit = C.create_exn ~name:"karatsuba_ofman_mult" (K.create ~config scope) in
       Rtl.output ~database ~output_mode:(To_file filename) Verilog circuit)
;;

let command_montgomery_mult =
  Command.basic
    ~summary:"montgomery-mult"
    (let%map_open.Command ground_multiplier = flag_ground_multiplier
     and squarer = flag "squarer" no_arg ~doc:" Generate RTL for squarer instead"
     and filename = flag_filename in
     fun () ->
       let module M = Montgometry_mult377 in
       let module C = Circuit.With_interface (M.I) (M.O) in
       let scope = Scope.create ~flatten_design:false () in
       let database = Scope.circuit_database scope in
       let circuit =
         M.create
           ~config:
             { multiplier_config =
                 (if squarer
                 then
                   `Squarer
                     { Squarer.Config.level_radices = [ Radix_2; Radix_3; Radix_3 ]
                     ; ground_multiplier
                     }
                 else
                   `Multiplier
                     (Karatsuba_ofman_mult.Config.generate
                        ~ground_multiplier
                        [ Radix_2; Radix_3; Radix_3 ]))
             ; montgomery_reduction_config = Montgomery_reduction.Config.for_bls12_377
             }
           ~p:(Ark_bls12_377_g1.modulus ())
           scope
         |> C.create_exn
              ~name:(if squarer then "montgomery_square" else "montgomery_mult")
       in
       Rtl.output ~database ~output_mode:(To_file filename) Verilog circuit)
;;

let command_barrett_reduction =
  Command.basic
    ~summary:"Barrett Reduction"
    (let%map_open.Command filename = flag_filename in
     fun () ->
       let module B = Barrett_reduction377 in
       let module C = Circuit.With_interface (B.I) (B.O) in
       let scope = Scope.create ~flatten_design:false () in
       let database = Scope.circuit_database scope in
       let circuit =
         B.create
           ~config:Barrett_reduction.Config.for_bls12_377
           ~p:(Ark_bls12_377_g1.modulus ())
           scope
         |> C.create_exn ~name:"barrett_reduction"
       in
       Rtl.output ~database ~output_mode:(To_file filename) Verilog circuit)
;;

let command_barrett_mult =
  Command.basic
    ~summary:"Karatsuba multiplication + Barrett Reduction"
    (let%map_open.Command filename = flag_filename in
     fun () ->
       let module B = Barrett_mult377 in
       let module C = Circuit.With_interface (B.I) (B.O) in
       let scope = Scope.create ~flatten_design:false () in
       let database = Scope.circuit_database scope in
       let circuit =
         B.create
           ~config:
             { multiplier_config =
                 Montgomery_reduction.Config.for_bls12_377.multiplier_config
             ; barrett_reduction_config = Barrett_reduction.Config.for_bls12_377
             }
           ~p:(Ark_bls12_377_g1.modulus ())
           scope
         |> C.create_exn ~name:"barrett_mult"
       in
       Rtl.output ~database ~output_mode:(To_file filename) Verilog circuit)
;;

let () =
  [ "specialized-43x43-multiplier", command_specialized_43x43_multiplier
  ; "verilog-43x43-multiplier", command_verilog_43x43_multiplier
  ; "karatsuba-ofman-mult", command_karatsuba_ofman_mult
  ; "montgomery-mult", command_montgomery_mult
  ; "barrett-reduction", command_barrett_reduction
  ; "barrett-mult", command_barrett_mult
  ]
  |> Command.group ~summary:"generate verilog"
  |> Command_unix.run
;;
