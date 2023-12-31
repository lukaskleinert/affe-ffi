(* This file contains all the common code used by the languages implemented in the PL Zoo. *)

type location =
  | Location of Lexing.position * Lexing.position (** delimited location *)
  | Nowhere (** no location *)

type 'a located = { data : 'a ; loc : location }

let make_location loc1 loc2 = Location (loc1, loc2)

let location_of_lex lex =
  Location (Lexing.lexeme_start_p lex, Lexing.lexeme_end_p lex)

let locate ?(loc=Nowhere) x = { data = x; loc = loc }

(** Exception [Error (loc, err, msg)] indicates an error of type [err] with error message
    [msg], occurring at location [loc]. *)
exception Error of (location * string * string)

(** [error ~loc ~kind] raises an error of the given [kind]. The [kfprintf] magic allows
    one to write [msg] using a format string. *)
let error ?(kind="Error") ?(loc=Nowhere) =
  let k _ =
    let msg = Format.flush_str_formatter () in
      raise (Error (loc, kind, msg))
  in
  Format.kfprintf k Format.str_formatter

let print_parens ?(max_level=9999) ?(at_level=0) ppf =
  if max_level < at_level then
    begin
      Format.fprintf ppf "(@[" ;
      Format.kfprintf (fun ppf -> Format.fprintf ppf "@])") ppf
    end
  else
    begin
      Format.fprintf ppf "@[" ;
      Format.kfprintf (fun ppf -> Format.fprintf ppf "@]") ppf
    end

let print_location loc ppf =
  match loc with
  | Nowhere ->
      Format.fprintf ppf "unknown location"
  | Location (begin_pos, end_pos) ->
      let begin_char = begin_pos.Lexing.pos_cnum - begin_pos.Lexing.pos_bol in
      let end_char = end_pos.Lexing.pos_cnum - begin_pos.Lexing.pos_bol in
      let begin_line = begin_pos.Lexing.pos_lnum in
      let filename = begin_pos.Lexing.pos_fname in

      if String.length filename != 0 then
        Format.fprintf ppf "file %S, line %d, charaters %d-%d" filename begin_line begin_char end_char
      else
        Format.fprintf ppf "line %d, characters %d-%d" (begin_line - 1) begin_char end_char

(** A fatal error reported by the toplevel. *)
let fatal_error msg = error ~kind:"Fatal error" msg

(** A syntax error reported by the toplevel *)
let syntax_error ?loc msg = error ~kind:"Syntax error" ?loc msg

(** Print a message at a given location [loc] of message type [msg_type]. *)
let print_message ?(loc=Nowhere) msg_type =
  match loc with
  | Location _ ->
     Format.eprintf "%s at %t:@\n" msg_type (print_location loc) ;
     Format.kfprintf (fun ppf -> Format.fprintf ppf "@.") Format.err_formatter
  | Nowhere ->
     Format.eprintf "%s: " msg_type ;
     Format.kfprintf (fun ppf -> Format.fprintf ppf "@.") Format.err_formatter

(** Print the caught error *)
let print_error (loc, err_type, msg) = print_message ~loc err_type "%s" msg

let print_info msg =
  Format.printf msg

type filename = string

module type LANGUAGE =
sig
  val name : string
  type command
  type environment
  val options : (Arg.key * Arg.spec * Arg.doc) list
  val initial_environment : environment
  val read_more : string -> bool
  val file_parser : (Lexing.lexbuf -> command list) option
  val toplevel_parser : (Lexing.lexbuf -> command) option
  val exec :
    (environment -> filename -> environment) ->
    environment -> command -> environment
  val ffi : Format.formatter -> command list -> unit
end

module Main (L : LANGUAGE) =
struct

  module History = struct
    let filename = Sys.getenv "HOME" ^ "/." ^ L.name ^ ".history"

    let load () = ignore (LNoise.history_load ~filename)

    (* let res = function Ok x -> x | Error s -> error "%s" s *)
    let add s =
      LNoise.history_add s |> ignore ;
      LNoise.history_save ~filename |> ignore ;
  end
    

  (** Should the interactive shell be run? *)
  let interactive_shell = ref true

  (** The usage message. *)
  let usage =
    match L.file_parser with
    | Some _ -> "Usage: " ^ L.name ^ " [option] ... [file] ..."
    | None   -> "Usage:" ^ L.name ^ " [option] ..."

  (** A list of files to be loaded and run. *)
  let files = ref []

  (** Add a file to the list of files to be loaded, and record whether it should
      be processed in interactive mode. *)
  let add_file filename = (files := filename :: !files)

  let (affiout : filename option ref) = ref None
  let set_affiout str = (affiout := Some str)

  (** Command-line options *)
  let options = Arg.align ([
    ("-v",
     Arg.Unit (fun () ->
       print_endline (L.name ^ " " ^ "(" ^ Sys.os_type ^ ")");
       exit 0),
     " Print language information and exit");
    ("-n",
     Arg.Clear interactive_shell,
     " Do not run the interactive toplevel");
    ("-l",
     Arg.String (fun str -> add_file str),
     "<file> Load <file> into the initial environment");
    ("-a",
     Arg.String (fun str -> set_affiout str),
     "<file> Set <file> as output file for compiled ocaml code"
    )
  ] @
  L.options)

  (** Treat anonymous arguments as files to be run. *)
  let anonymous str =
    add_file str;
    interactive_shell := false

  (** Parse the contents from a file, using a given [parser]. *)
  let rec read_file parser fd fn =
  try
    let fn = match fd with
      | Some fd -> Filename.concat fd fn 
      | None -> fn in
    let fh = open_in fn in
    let lex = Lexing.from_channel fh in
    lex.Lexing.lex_curr_p <- {lex.Lexing.lex_curr_p with Lexing.pos_fname = fn};
    try
      let terms = parser lex in
      close_in fh;
      terms
    with
      (* Close the file in case of any parsing errors. *)
      Error err -> close_in fh ; raise (Error err)
  with
    (* Any errors when opening or closing a file are fatal. *)
    Sys_error msg -> 
      match fd with
      | Some _ -> (try read_file parser None fn with Sys_error msg2 -> fatal_error "%s" msg2)
      | None -> fatal_error "%s" msg

  (** Parse input from toplevel, using the given [parser]. *)
  let read_toplevel parser () =
    let prompt = L.name ^ "> "
    and prompt_more = String.make (String.length L.name) ' ' ^ "> " in
    match LNoise.linenoise prompt with
    | None -> exit 0
    | Some s0 ->
      History.add s0;
      let rec aux acc =
        if L.read_more acc then match LNoise.linenoise prompt_more with
          | None -> exit 0
          | Some s ->
            History.add s;
            aux (acc ^ s)
        else begin
          parser @@ Lexing.from_string (acc ^ "\n")
        end
      in
      aux s0
          
  (** Parser wrapper that catches syntax-related errors and converts them to errors. *)
  let wrap_syntax_errors parser lex =
    try[@warning "-52"]
      parser lex
    with
      | Failure _ ->
        syntax_error ~loc:(location_of_lex lex) "unrecognised symbol"
      | _ ->
        syntax_error ~loc:(location_of_lex lex) "syntax error"

  (** Load directives from the given file. *)
  let rec use_file ffi_cmds dirname ctx filename =
    match L.file_parser with
    | Some f ->
       let cmds =
        read_file (wrap_syntax_errors f) (Some dirname) filename
       in
       let dirname = Filename.concat dirname (Filename.dirname filename) in
       let ctx = List.fold_left (L.exec (use_file ffi_cmds dirname)) ctx cmds in (
        match !affiout with
        | None -> ctx
        | Some _ ->
          L.ffi ffi_cmds cmds;
          ctx
       )
    | None ->
       fatal_error "Cannot load files, only interactive shell is available"

  (** Interactive toplevel *)
  let toplevel ctx =
    let eof = match Sys.os_type with
      | "Unix" | "Cygwin" -> "Ctrl-D"
      | "Win32" -> "Ctrl-Z"
      | _ -> "EOF"
    in
      let toplevel_parser =
        match L.toplevel_parser with
        | Some p -> p
        | None -> fatal_error "I am sorry but this language has no interactive toplevel."
      in
      Format.printf "%s -- programming languages zoo@." L.name ;
      Format.printf "Type %s to exit@." eof ;
      try
        let ctx = ref ctx in
          while true do
            try
              let cmd = read_toplevel (wrap_syntax_errors toplevel_parser) () in
              let empty_fmt = Format.make_formatter (fun _ _ _ -> ()) (fun _ -> ()) in
              (* TODO: affi output in interactive mode? *)
              ctx := L.exec (use_file empty_fmt "./") !ctx cmd
            with
              | Error err -> print_error err
              | Sys.Break -> prerr_endline "Interrupted."
          done
      with End_of_file -> ()

  (** Main program *)
  let main () =
    LNoise.set_multiline true;
    History.load () ;
    (* Intercept Ctrl-C by the user *)
    LNoise.catch_break true;
    (* Parse the arguments. *)
    Arg.parse options anonymous usage;
    (* Files were listed in the wrong order, so we reverse them *)
    files := List.rev !files;
    (* Set the maximum depth of pretty-printing, after which it prints ellipsis. *)
    Format.set_max_boxes 42 ;
    Format.set_ellipsis_text "..." ;
    Format.set_margin 80 ;
    Format.set_max_indent 30 ;
    try
      let cmd_buf = Buffer.create 16 in
      let cmd_fmt = Format.formatter_of_buffer cmd_buf in
      (* Run and load all the specified files. *)
      let ctx = List.fold_left (use_file cmd_fmt "./") L.initial_environment !files in
        if !interactive_shell then toplevel ctx;
      match !affiout with
      | None -> ()
      | Some s -> let oc = open_out s in
        Fmt.pf (Format.formatter_of_out_channel oc) "%s@.\n" (Buffer.contents cmd_buf);
        close_out oc
      
    with
        Error err -> print_error err; exit 1

  (** needed only in implementation zoo/web *)
  let load_files _ = ()

end

(* 
MIT License

Copyright © 2016 Andrej Bauer, Matija Pretnar

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*)
