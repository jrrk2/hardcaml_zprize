open Hardcaml
open Hardcaml_axi

module I : sig
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; host_scalars_to_fpga : 'a Axi512.Stream.Source.t
    ; ddr_points_to_fpga : 'a Axi512.Stream.Source.t
    ; host_to_fpga_dest : 'a Axi512.Stream.Dest.t
    }
  [@@deriving sexp_of, hardcaml]
end

module O : sig
  type 'a t =
    { host_scalars_to_fpga_dest : 'a Axi512.Stream.Dest.t
    ; ddr_points_to_fpga_dest : 'a Axi512.Stream.Dest.t
    ; host_to_fpga : 'a Axi512.Stream.Source.t
    }
  [@@deriving sexp_of, hardcaml]
end

val hierarchical : ?instance:string -> Scope.t -> Signal.t Interface.Create_fn(I)(O).t
