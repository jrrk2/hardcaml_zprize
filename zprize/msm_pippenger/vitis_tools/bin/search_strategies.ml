open Core
open Async
module Vitis_utils = Msm_pippenger.Vitis_util

module Which_experiment = struct
  type t = A [@@deriving sexp]

  let arg_type = Command.Arg_type.create (fun x -> t_of_sexp (Atom x))

  let linker_config_args = function
    | A ->
      [ { Vitis_utils.Linker_config_args.synthesis_strategy =
            Some Flow_AlternateRoutability
        ; implementation_strategy = Some Congestion_SSI_SpreadLogic_high
        ; opt_design_directive = Some Explore
        ; route_design_directive = Some AlternateCLBRouting
        ; place_design_directive = Some Explore
        ; phys_opt_design_directive = Some AggressiveExplore
        ; kernel_frequency = 310
        ; post_route_phys_opt_design_directive = Some AggressiveExplore
        ; route_design_tns_cleanup = true
        }
      ]
  ;;
end

let search_for_vivado_log_filename ~build_dir =
  let%bind.Deferred.Or_error lines =
    Process.run_lines ~prog:"find" ~args:[ build_dir; "-name"; "vivado.log" ] ()
  in
  match
    List.find_map lines ~f:(fun line ->
      let line = String.strip line in
      if Core.String.is_substring ~substring:"link/vivado/vpl/vivado.log" line
      then Some line
      else None)
  with
  | None -> return (Or_error.error_s [%message "Cannot find linker vpl vivado.log"])
  | Some x -> return (Ok x)
;;

let run_build ~template_dir ~build_dir ~build_id ~linker_config =
  (* TOOO(fyquah): Reuse dir from last good build rather than the template *)
  printf "Starting build with build id = %s\n" build_id;
  let build_dir = build_dir ^/ build_id in
  let%bind.Deferred.Or_error () =
    match%map Async_unix.Sys.file_exists build_dir with
    | `Yes ->
      Or_error.errorf
        "Cannot start build in a directory that already exists! %s"
        build_dir
    | `No -> Ok ()
    | `Unknown ->
      Or_error.errorf
        "Cannot determine if build dir exists (Incorrect permissions?) %s"
        build_dir
  in
  (* Copy template_dir to build_dir/build_id *)
  let%bind.Deferred.Or_error (_ : string) =
    Process.run ~prog:"cp" ~args:[ "-r"; template_dir; build_dir ] ()
  in
  (* Generate the linker config into msm_pippenger.cfg *)
  let%bind () =
    let%bind wrt = Writer.open_file (build_dir ^/ "msm_pippenger.cfg") in
    Msm_pippenger.Vitis_util.write_linker_config
      linker_config
      ~output_string:(Writer.write wrt);
    Writer.close wrt
  in
  (* Run ./compile_hw.sh from build_dir/build_id *)
  let%bind.Deferred.Or_error (_ : string) =
    Process.run ~working_dir:build_dir ~prog:"./compile_hw.sh" ~args:[] ()
  in
  (* Guess the vivado.log in vpl/ *)
  let%bind.Deferred.Or_error vivado_log_filename =
    search_for_vivado_log_filename ~build_dir
  in
  (* Parse vivado.log to load the WNS or something? *)
  let%bind.Deferred.Or_error timing_summary =
    let%map vivado_log_lines = Async.Reader.file_lines vivado_log_filename in
    match Vitis_utils.parse_vivado_logs_for_timing_summary ~vivado_log_lines with
    | None ->
      Or_error.errorf
        "Failed to find timing summary in the vivado log file %s"
        vivado_log_filename
    | Some x -> Ok x
  in
  printf
    !"Completed build (build id: %s) - performance: %{Bignum.to_string_hum}MHz\n"
    build_id
    (Vitis_utils.Timing_summary.achieved_frequency
       timing_summary
       ~compile_frequency_in_mhz:(Bignum.of_int linker_config.kernel_frequency));
  return (Ok timing_summary)
;;

let run_all_builds_for_experiment ~max_jobs ~template_dir ~build_dir ~which_experiment =
  Deferred.List.mapi
    (Which_experiment.linker_config_args which_experiment)
    ~how:(`Max_concurrent_jobs max_jobs)
    ~f:(fun i linker_config ->
    run_build
      ~template_dir
      ~build_dir
      ~build_id:("build-" ^ Int.to_string i)
      ~linker_config)
;;

let command_build =
  Command.async
    ~summary:
      "Spawns various builds of the msm with various strategies and report the \
       implementation results in the end."
    (let%map_open.Command build_dir =
       flag "build-dir" (required string) ~doc:" Directory to perform builds in"
     and template_dir = flag "template-dir" (required string) ~doc:" Template directory"
     and which_experiment =
       flag
         "which-experiment"
         (required Which_experiment.arg_type)
         ~doc:" Which experiment to run"
     and max_jobs =
       flag
         "max-jobs"
         (required int)
         ~doc:" Max number of parallel build jobs to run concurrently"
     in
     fun () ->
       if not (Sys_unix.file_exists_exn template_dir)
       then raise_s [%message "Template does not exist!" (template_dir : string)];
       let%bind (_ : string) =
         printf "Building @default in the template_dir %s...\n" template_dir;
         Process.run_exn
           ~prog:"dune"
           ~args:[ "build"; "@" ^ template_dir ^/ "default" ]
           ()
       in
       (* TOOO(fyquah): Dump some summary? *)
       let%bind _results =
         run_all_builds_for_experiment
           ~template_dir
           ~build_dir
           ~max_jobs
           ~which_experiment
       in
       return ())
;;

let () = Command.group ~summary:"" [ "build", command_build ] |> Command_unix.run