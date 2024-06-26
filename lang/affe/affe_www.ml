let doc =
  let open Js_of_ocaml_tyxml.Tyxml_js in
  [%html{|
<p>
  Welcome to the online demo of the Affe language!
</p>
<p>
  The original implementation of the Affe language was taken from
  <a href="https://github.com/Drup/pl-experiments">https://github.com/Drup/pl-experiments</a>.
  This version features an OCaml-ffi and Affe to OCaml translator.
</p>
<p>
 This language aims to prevent linearity violations, notably bugs such as 
 use-after-free. Affe is an ML-like language similar to OCaml. 
 In particular, Affe is functional with arbitrary side effects and
 complete type inference (i.e., users never need to write type annotations).
 Beware, this is a prototype: error messages
(and the UI in general) are research-quality.
</p>
<h2> How to use </h2>
<p>
You can find a list of examples below. "Run" runs the typing and
translation to OCaml.
The result of the typing (or the appropriate type error) is displayed
on the top right. The OCaml code is displayed on the bottom left.
"Run OCaml" runs the currently displayed OCaml code with js_of_ocaml-toplevel 
and displays the output of that on the bottom right.
</p>
<p>
  <em>Have fun!</em>
</p>
|}]



let l = [
  "intro.affe";
  "arraydef.affe";
  "basics.affe";
  "constraints.affe";
  "cow.affe";
  "example.affe";
  "fail.affe";
  "linstr.affe";
  "moduleimport.affe";
  "nested_module.affe";
  "nonlexical.affe";
  "optstrlist.affe";
  "patmatch.affe";
  "pool.affe";
  "queuedef.affe";
  "region.affe";
  "sessions.affe";
  "sudoku.affe";
  "test_un.affe";
  "unused.affe";
]

let () =
  Js_of_ocaml_tyxml.Tyxml_js.Register.id "content" doc;
  Printer.debug := false ;
  Affe_lang.load_files l ;
  Affe_lang.main ()

(* "builtin" ocaml modules are added in zoo/web/jsootop/jsootop.ml *)
