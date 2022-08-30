open Base
open Hardcaml
open Field_ops_lib

module For_bls12_377 = struct
  let p = Ark_bls12_377_g1.modulus ()

  let montgomery_reduction_config =
    { Montgomery_reduction.Config.multiplier_config =
        Karatsuba_ofman_mult.Config.generate
          ~ground_multiplier:(Verilog_multiply { latency = 3 })
          [ Radix_3; Radix_3 ]
    ; half_multiplier_config =
        { level_radices = [ Radix_3; Radix_3; Radix_2 ]
        ; ground_multiplier = Hybrid_dsp_and_luts { latency = 3 }
        }
    ; adder_depth = 3
    ; subtractor_depth = 3
    }
  ;;

  let barrett_reduction_config =
    { Barrett_reduction.Config.approx_msb_multiplier_config =
        { level_radices = [ Radix_3; Radix_3; Radix_2 ]
        ; ground_multiplier = Verilog_multiply { latency = 2 }
        }
    ; half_multiplier_config =
        { level_radices = [ Radix_3; Radix_3; Radix_2 ]
        ; ground_multiplier = Hybrid_dsp_and_luts { latency = 3 }
        }
    ; subtracter_stages = 3
    }
  ;;

  let square : Ec_fpn_ops_config.fn =
    let config =
      { Squarer.Config.level_radices = [ Radix_3; Radix_3; Radix_2 ]
      ; ground_multiplier = Hybrid_dsp_and_luts { latency = 3 }
      }
    in
    let latency = Squarer.Config.latency config in
    let impl ~scope ~clock ~enable x y =
      assert (Option.is_none y);
      Squarer.hierarchical ~config ~clock ~enable ~scope x
    in
    { impl; latency }
  ;;

  let multiply : Ec_fpn_ops_config.fn =
    let config =
      Karatsuba_ofman_mult.Config.generate
        [ Radix_3; Radix_3 ]
        ~ground_multiplier:Specialized_43_bit_multiply
    in
    let latency = Karatsuba_ofman_mult.Config.latency config in
    let impl ~scope ~clock ~enable x y =
      Karatsuba_ofman_mult.hierarchical
        ~enable
        ~config
        ~scope
        ~clock
        x
        (`Signal (Option.value_exn y))
    in
    { latency; impl }
  ;;

  let montgomery_reduce : Ec_fpn_ops_config.fn =
    let config = montgomery_reduction_config in
    let latency = Montgomery_reduction.Config.latency config in
    let impl ~scope ~clock ~enable x y =
      assert (Option.is_none y);
      Montgomery_reduction.hierarchical ~config ~p ~scope ~clock ~enable x
    in
    { impl; latency }
  ;;

  let barrett_reduce : Ec_fpn_ops_config.fn =
    let config = barrett_reduction_config in
    let impl ~scope ~clock ~enable mult_value y =
      assert (Option.is_none y);
      let { With_valid.valid = _; value } =
        Barrett_reduction.hierarchical
          ~scope
          ~p
          ~clock
          ~enable
          ~config
          { valid = Signal.vdd; value = mult_value }
      in
      value
    in
    let latency = Barrett_reduction.Config.latency config in
    { impl; latency }
  ;;

  let ec_fpn_ops_with_montgomery_reduction =
    let reduce = montgomery_reduce in
    { Ec_fpn_ops_config.multiply; square; reduce; p }
  ;;

  let ec_fpn_ops_with_barrett_reduction =
    let reduce = barrett_reduce in
    { Ec_fpn_ops_config.multiply; square; reduce; p }
  ;;
end