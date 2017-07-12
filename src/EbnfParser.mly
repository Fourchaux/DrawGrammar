%{
  open General.Abbr
  module Lexing = OCamlStandard.Lexing
  module Printf = OCamlStandard.Printf
  module Pervasives = OCamlStandard.Pervasives

  open Grammar
  open Grammar.Rule
  open Grammar.Definition
%}

(* http://www.cl.cam.ac.uk/~mgk25/iso-14977.pdf *)

%token <int> INTEGER
%token <string> META_IDENTIFIER
%token <string> SPECIAL_SEQUENCE
%token <string> TERMINAL_STRING
%token CONCATENATE_SYMBOL
%token DEFINING_SYMBOL
%token DEFINITION_SEPARATOR_SYMBOL
%token EOF
%token EXCEPT_SYMBOL
%token REPETITION_SYMBOL
%token START_GROUP_SYMBOL, END_GROUP_SYMBOL
%token START_OPTION_SYMBOL, END_OPTION_SYMBOL
%token START_REPEAT_SYMBOL, END_REPEAT_SYMBOL
%token TERMINATOR_SYMBOL

%start syntax

%type <Grammar.t> syntax

%%

(* 4.2: syntax = syntax rule, {syntax rule}; *)
syntax:
  | rules=nonempty_list(syntax_rule) EOF
    { {rules} }

(* 4.3: syntax rule = meta identifier, defining symbol, definitions list, terminator symbol; *)
syntax_rule:
  | name=META_IDENTIFIER DEFINING_SYMBOL definition=definitions_list TERMINATOR_SYMBOL
    { {name; definition} }

(* 4.4: definitions list = single definition, {definition separator symbol, single definition}; *)
definitions_list:
  | elements=separated_nonempty_list(DEFINITION_SEPARATOR_SYMBOL, single_definition)
    {
      Alternative {Alternative.elements}
    }

(* 4.5: single definition = syntactic term, {concatenate symbol, syntactic term}; *)
single_definition:
  | elements=separated_nonempty_list(CONCATENATE_SYMBOL, syntactic_term)
    {
      Sequence {Sequence.elements}
    }

(* 4.6: syntactic term = syntactic factor, [except symbol, syntactic exception]; *)
syntactic_term:
  | base=syntactic_factor except=option(preceded(EXCEPT_SYMBOL, syntactic_exception))
    {
      match except with
        | None -> base
        | Some except -> Except {Except.base; except}
    }

(* 4.7: syntactic exception = ? a syntactic factor that could be replaced by a syntactic factor containing no meta-identifiers ?; *)
syntactic_exception:
  | factor=syntactic_factor
    { factor }

(* 4.8: syntactic factor = [integer, repetition symbol], syntactic primary; *)
syntactic_factor:
  | repeat=boption(terminated(INTEGER, REPETITION_SYMBOL)) primary=syntactic_primary
    {
      if repeat then
        Repetition {Repetition.forward=primary; backward=Null}
      else
        primary
    }

(* 4.10: syntactic primary = optional sequence | repeated sequence | grouped sequence | meta identifier | terminal string | special sequence | empty sequence; *)
syntactic_primary:
  | primary=optional_sequence { primary }
  | primary=repeated_sequence { primary }
  | primary=grouped_sequence { primary }
  | name=META_IDENTIFIER { NonTerminal {NonTerminal.name} }
  | value=TERMINAL_STRING { Terminal {Terminal.value} }
  | value=SPECIAL_SEQUENCE { Special {Special.value} }
  | primary=empty_sequence { primary }

(* 4.11: optional sequence = start option symbol, definitions list, end option symbol; *)
optional_sequence:
  | sequence=delimited(START_OPTION_SYMBOL, definitions_list, END_OPTION_SYMBOL)
    {
      Alternative {Alternative.elements=[Null; sequence]}
    }

(* 4.12: repeated sequence = start repeat symbol, definitions list, end repeat symbol; *)
repeated_sequence:
  | backward=delimited(START_REPEAT_SYMBOL, definitions_list, END_REPEAT_SYMBOL)
    {
      Repetition {Repetition.forward=Null; backward}
    }

(* 4.13: grouped sequence = start group symbol, definitions list, end group symbol; *)
grouped_sequence:
  | sequence=delimited(START_GROUP_SYMBOL, definitions_list, END_GROUP_SYMBOL)
    {
      sequence
    }

(* 4.21: empty sequence =; *)
empty_sequence:
  | (* empty *)
    {
      Null
    }
