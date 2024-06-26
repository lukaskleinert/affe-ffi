(* type string   *)

(* val print_int  *)

(* val print_endline  *)

(* type ('a) option = None | Some of 'a *)

let func = (fun () -> print_int 4)
(*
  type string  
  val print_int 
  val print_endline 
  type ('a) option = None | Some of 'a
*)
(*
extern Foo
  val bar 
  val print 
  type ('a) option = None | Some of 'a
*)
(* val Foo.bar  *)

(* val Foo.print  *)

(* type ('a) Foo.option = Foo.None | Foo.Some of 'a *)

let printbar = (fun () -> Foo.print Foo.bar)
(*
extern Array
  val init 
  val get 
*)
let arr = (Array.init 1 (fun _i -> 2))
let print i s = ( print_int i ; print_endline s )
let ex = ( "!" )
type ('a, 'b) either = Left of 'a | Right of 'b
let two =
  (let x = Left true in
   match x with
     | Left (true) -> Array.get arr 0
     | _u -> 0)
let main = (let () = func ();
                     print two ex;
                     printbar () in ())

