%{
open Syntax

let mk_lambda l body = List.fold_right (fun n e -> Lambda (n, e)) l body
let mk_let r name args e1 e2 =
  let e1 = match args with [] -> e1 | l -> mk_lambda l e1 in
  Let (r, PVar name, e1, e2)
let mk_decl rec_flag name args e =
  let expr = match args with [] -> e | l -> mk_lambda l e in
  ValueDecl {rec_flag; name; expr}

let mk_binop op a b : expr = App (op, [a;b])

let mk_var s : expr = Var (Name.dummy s)
let mk_get a i : expr = App (mk_var "array_get", [Tuple [a;i]])
let mk_set a i x : expr = App (mk_var "array_set", [Tuple [a;i;x]])
%}

%token EOF SEMISEMI
%token YTOK
%token <string> IDENT
%token <string> TYIDENT
%token <string> UIDENT
%token <string> MIDENT
%token <string> MUIDENT
%token <int> INT
%token <string> STRING
%token UN AFF LIN
%token UNDERSCORE
%token DOT
%token STAR DIV
%token EQUAL PLUS MINUS
%token LPAREN RPAREN
%token LACCO RACCO
%token LBRACKPIPE PIPERBRACK
%token LET IN REC
%token <Syntax.match_spec> MATCH
%token SEMI
%token BAR
%token TYPE VAL WITH IMPORT
%token EXTERN
%token <string> OCAML
%token RIGHTARROW LEFTARROW FUN BIGRIGHTARROW
%token COMMA DOUBLECOLON OF
%token LESS GREATER
%token DASHLACCO RACCOGREATER
%token AND
%token PERCENT
%token ANDBANG
%token FORALL

%nonassoc IN
%nonassoc LEFTARROW
%right SEMI
%right RIGHTARROW DASHLACCO RACCOGREATER
%nonassoc FUN
/* %left FUNAPP */
%left PLUS MINUS
%right STAR DIV
%nonassoc LESS GREATER EQUAL
/* %nonassoc below_DOT */
/* %nonassoc DOT */
%nonassoc
  /* AND ANDBANG INT */ IDENT  MIDENT /* UIDENT LPAREN LACCO LBRACKPIPE YTOK ALLOC */

%start file
%type <Syntax.command list> file

%start toplevel
%type <Syntax.command> toplevel

%type <expr> expr
%%
file: list(command) EOF { $1 }
toplevel: command SEMISEMI { $1 }

command:
  | LET r=rec_flag name=name args=list(simple_pattern) EQUAL expr=expr
    { mk_decl r name args expr }
  | VAL name=name DOUBLECOLON typ=type_scheme
    { ValueDef { name ; typ } }
  | typdecl=type_decl { typdecl }
  | IMPORT s = STRING { Import s }
  | EXTERN VAL name=name DOUBLECOLON typ=type_scheme
    { Extern ({ name = None ; id = -1 }, [ValueDef { name ; typ }]) }
  | EXTERN typedecl=type_decl code=OCAML
    { OCAML (typedecl, [], code) }
  | EXTERN typedecl=type_decl
    { Extern ({ name = None ; id = -1 }, [typedecl]) }
  | EXTERN LPAREN l=list(command) RPAREN { Extern ({ name = None ; id = -1 }, l) }
  | EXTERN n=UIDENT LPAREN l=list(module_val) RPAREN { Extern (Name.dummy n, l) }
  | EXTERN name=name args=list(simple_pattern) DOUBLECOLON typ=type_scheme EQUAL code=OCAML
    { OCAML ((ValueDef { name ; typ }),  args,  code) }

module_val:
  | VAL name=name DOUBLECOLON typ=type_scheme
    { ValueDef { name ; typ } }
  | typdecl=type_decl { typdecl }


expr:
  | e=simple_expr /* %prec below_DOT */
    { e }
  | e1=expr SEMI e2=expr
    { Sequence (e1, e2) }
  | f=simple_expr l=list_expr /* %prec FUNAPP */
    { App (f,List.rev l) }
  | e1=expr op=binop e2=expr
    { mk_binop op e1 e2 }
  | LET r=rec_flag name=name args=nonempty_list(simple_pattern) EQUAL e1=expr IN e2=expr
    { mk_let r name args e1 e2 }
  | LET p=pattern EQUAL e1=expr IN e2=expr
    { Let (NonRec, p, e1, e2) }
  | b=MATCH e=expr WITH LACCO l=cases RACCO
    { Match (b,e, l) }
  | FUN l=list(simple_pattern) RIGHTARROW body=expr
    { mk_lambda l body }
  | s=simple_expr DOT LPAREN i=expr RPAREN LEFTARROW e=expr
    { mk_set s i e }

simple_expr:
  | c=constant { Constant c }
  | name=uname { Constructor name }
  | name=name { Var name }
  | LPAREN RPAREN { Builtin.unit }
  | LPAREN l=separated_nonempty_list(COMMA,expr) RPAREN
    { match l with
      | [e] -> e
      | l -> Tuple l
    }
  | LACCO e=expr RACCO { Region (Name.Map.empty, e) }
  | LBRACKPIPE l=separated_list(SEMI, simple_expr) PIPERBRACK { Array l }
  | b=borrow name=name { Borrow (b, name) }
  | AND b=borrow name=name { ReBorrow (b, name) }
  | s=simple_expr DOT LPAREN i=expr RPAREN { mk_get s i }

cases: ioption(BAR) l=separated_nonempty_list(BAR, case) { l }
case:
  p=pattern RIGHTARROW e=expr { p,e }

%inline binop:
  | PLUS {Constant (Primitive "+")}
  | MINUS {Constant (Primitive "-")}
  | STAR {Constant (Primitive "*")}
  | DIV {Constant (Primitive "/")}
  | LESS {Constant (Primitive "<")}
  | GREATER {Constant (Primitive ">")}
  | EQUAL {Constant (Primitive "=")}

%inline rec_flag:
  | { NonRec }
  | REC { Rec }

pattern:
  | p=simple_pattern { p }
  | constr=uname p=pattern { PConstr (constr, Some p) }

simple_pattern:
  | v=name { PVar v }
  | UNDERSCORE { PAny }
  | LPAREN RPAREN { PUnit }
  | constr=uname { PConstr (constr, None) }
  | LPAREN p=pattern RPAREN { p }
  | LPAREN l=separated_nontrivial_llist(COMMA,pattern) RPAREN { PTuple l }

%inline borrow:
  | AND { Immutable }
  | ANDBANG { Mutable }

list_expr:
  | simple_expr  { [$1] }
  | list_expr simple_expr { $2 :: $1 }

constant:
  | i=INT { Int i }
  | PERCENT s=IDENT { Primitive s }
  | YTOK { Y }


name:
  | name=IDENT { Name.dummy name }
  | mod_name=MIDENT { Name.dummy mod_name }
uname:
  | name=UIDENT { Name.dummy name }
  | mod_name=MUIDENT { Name.dummy mod_name }
type_var:
  | name=TYIDENT { Name.dummy name }
kind_var:
  | name=TYIDENT { Name.dummy name }

type_decl:
  | TYPE
     params=type_var_bindings name=name kind=kind_annot
     constructor=maybe_constructors constraints=maybe_constraints
    { TypeDecl {name; params; constructor ; constraints ; kind} }

// type_decl_without_cons:
//   | TYPE
//      params=type_var_bindings name=name kind=kind_annot
//     { TypeDecl {name; params; constructor=[]; constraints=C.ctrue; kind} }

maybe_constructors:
  | { [] }
  | EQUAL option(BAR) l=separated_list(BAR, constructor_decl)
    { l }
constructor_decl:
  | name=uname OF e=type_expr_with_constraint
    { let constraints, typ = e in
      {T. name; constraints; typ=(Some typ)}
    }
  | name=uname
    {
      {T. name; constraints=C.ctrue; typ=None}
    }

maybe_constraints:
  | { C.ctrue }
  | WITH c=constraints { c }

type_scheme:
  | p=param_list
    e=type_expr_with_constraint
    { let kvars, tyvars = p in
      let constraints, typ = e in
      {T. kvars; tyvars; constraints; typ}
    }

%inline param_list:
  | { [], [] }
  | FORALL kparams=list(kind_var) params=list(type_quantifier) DOT { kparams, params}

type_expr_with_constraint:
  | t=type_expr { (C.ctrue, t) }
  | c=constraints BIGRIGHTARROW t=type_expr { (c, t) }

type_expr:
  | t=simple_type_expr { t }
  | l=separated_nontrivial_llist(STAR, simple_type_expr) { T.Tuple l }
  | t1=type_expr k=arrow t2=type_expr { T.Arrow (t1, k, t2) }
simple_type_expr:
  | t=simple_type_expr_no_paren { t }
  | LPAREN e=type_expr RPAREN %prec FUN
    { e }
simple_type_expr_no_paren:
  | n=type_var { T.Var n }
  | n=name { T.App (n, []) }
  | t=simple_type_expr n=name { T.App (n, [t]) }
  | b=borrow LPAREN k=kind_expr COMMA t=type_expr RPAREN
    { T.Borrow (b,k,t) }
  | LPAREN p=type_list RPAREN n=name
    { T.App (n, p) }

%inline type_list:
  tys = inline_reversed_separated_nonempty_llist(COMMA, type_expr) { List.rev tys }
  
%inline arrow:
  | RIGHTARROW { K.Un }
  | DASHLACCO k=kind_expr RACCOGREATER { k }

kind_annot:
  | { K.Unknown }
  | DOUBLECOLON k=kind_expr { k }

kind_expr:
  | n=kind_var { K.KVar n }
  | UN { K.Un }
  | AFF { K.Aff }
  | LIN { K.Lin }
  | UNDERSCORE { K.Unknown }

constraints: l=separated_nonempty_list (COMMA, constr) { C.And l }
constr:
  | k1=kind_expr LESS k2=kind_expr { C.KindLEq (k1, k2) }
  | k1=kind_expr GREATER k2=kind_expr { C.KindLEq (k2, k1) }
  | t=type_expr DOUBLECOLON k=kind_expr { C.HasKind (t, k) }

type_quantifier:
  | LPAREN t=type_var_binding RPAREN {t}

type_var_bindings:
  | { [] }
  | LPAREN
    l=inline_reversed_separated_nonempty_llist(COMMA,type_var_binding)
    RPAREN
      { List.rev l }
type_var_binding:
  | ty=type_var DOUBLECOLON k=kind_expr { (ty, k) }


(* Generic parsing rules *)

reversed_separated_nonempty_llist(separator, X):
  xs = inline_reversed_separated_nonempty_llist(separator, X) { xs }

%inline inline_reversed_separated_nonempty_llist(separator, X):
  x = X
    { [ x ] }
| xs = reversed_separated_nonempty_llist(separator, X)
  separator
  x = X
    { x :: xs }

reversed_separated_nontrivial_llist(separator, X):
  xs = reversed_separated_nontrivial_llist(separator, X)
  separator
  x = X
    { x :: xs }
| x1 = X
  separator
  x2 = X
    { [ x2; x1 ] }

%inline separated_nontrivial_llist(separator, X):
  xs = rev(reversed_separated_nontrivial_llist(separator, X))
    { xs }
