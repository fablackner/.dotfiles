; Procedures: ]f [f to jump, vaf / vif to select
[
  (subroutine)
  (function)
  (module_procedure)
  (program)
] @function.outer

(subroutine
  (subroutine_statement)
  .
  _+ @function.inner
  .
  (end_subroutine_statement))

(function
  (function_statement)
  .
  _+ @function.inner
  .
  (end_function_statement))

(module_procedure
  (module_procedure_statement)
  .
  _+ @function.inner
  .
  (end_module_procedure_statement))

; Modules and types: ]c [c to jump, vac to select
[
  (module)
  (submodule)
  (derived_type_definition)
  (interface)
] @class.outer

; Loops
[
  (do_loop)
  (forall_statement)
] @loop.outer

(do_loop
  (do_statement)
  .
  _+ @loop.inner
  .
  (end_do_loop_statement))

; Conditionals
[
  (if_statement)
  (select_case_statement)
  (where_statement)
] @conditional.outer

(if_statement
  (parenthesized_expression) @conditional.inner)

; Calls and arguments: ]a [a to jump between arguments
[
  (subroutine_call)
  (call_expression)
] @call.outer

(argument_list
  (_) @parameter.inner)

(parameters
  (_) @parameter.inner)

(comment) @comment.outer
