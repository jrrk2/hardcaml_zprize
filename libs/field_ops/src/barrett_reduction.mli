open Hardcaml

module Config : sig
  type t =
    { approx_msb_multiplier_config : Approx_msb_multiplier.Config.t
    ; half_multiplier_config : Half_width_multiplier.Config.t
    ; subtracter_stages : int
    ; num_correction_steps : int
    }

  val latency : t -> int
  val for_bls12_377 : t
end

module With_interface (M : sig
  val bits : int
end) : sig
  val bits : int

  module I : sig
    type 'a t =
      { clock : 'a
      ; enable : 'a
      ; a : 'a
      ; valid : 'a
      }
    [@@deriving sexp_of, hardcaml]
  end

  module O : sig
    type 'a t =
      { a_mod_p : 'a
      ; valid : 'a
      }
    [@@deriving sexp_of, hardcaml]
  end

  val create : config:Config.t -> p:Z.t -> Scope.t -> Signal.t I.t -> Signal.t O.t
  val hierarchical : config:Config.t -> p:Z.t -> Scope.t -> Signal.t I.t -> Signal.t O.t
end

val hierarchical
  :  scope:Scope.t
  -> config:Config.t
  -> p:Z.t
  -> clock:Signal.t
  -> enable:Signal.t
  -> Signal.t With_valid.t
  -> Signal.t With_valid.t
