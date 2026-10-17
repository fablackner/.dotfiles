;; extends

; "end" takes the color of the construct it closes
(end_do_loop_statement "end" @keyword.repeat)
(end_forall_statement "end" @keyword.repeat)
(end_if_statement "end" @keyword.conditional)
(end_where_statement "end" @keyword.conditional)
(end_select_statement "end" @keyword.conditional)
[
  (end_subroutine_statement "end" @keyword.function)
  (end_function_statement "end" @keyword.function)
  (end_program_statement "end" @keyword.function)
  (end_module_procedure_statement "end" @keyword.function)
]
[
  (end_module_statement "end" @keyword.type)
  (end_submodule_statement "end" @keyword.type)
  (end_type_statement "end" @keyword.type)
  (end_interface_statement "end" @keyword.type)
]
(end_associate_statement "end" @keyword)
(end_block_construct_statement "end" @keyword)

; Missing keywords
[
  "select"
  "case"
] @keyword.conditional

[
  "go"
  "to"
  "endblock"
  "critical"
  "endcritical"
  "operator"
  "assignment"
] @keyword

"only" @keyword.import

"entry" @keyword.function

[
  "allocate"
  "deallocate"
  "nullify"
  "inquire"
  "rewind"
  "backspace"
  "flush"
] @function.builtin

; Intrinsic procedures (array indexing and calls share call_expression,
; so only known intrinsics are highlighted)
(call_expression
  .
  (identifier) @function.builtin
  (#match? @function.builtin "\\v\\c^(size|shape|lbound|ubound|allocated|associated|present|kind|len|len_trim|trim|adjustl|adjustr|index|scan|verify|repeat|abs|sqrt|exp|log|log10|sin|cos|tan|asin|acos|atan|atan2|sinh|cosh|tanh|min|max|minval|maxval|minloc|maxloc|sum|product|count|any|all|dot_product|matmul|transpose|conjg|real|aimag|cmplx|dble|int|nint|floor|ceiling|mod|modulo|sign|huge|tiny|epsilon|precision|reshape|spread|pack|unpack|merge|cshift|eoshift|reduce|norm2|iand|ior|ieor|not|ishft|btest|ibset|ibclr|popcnt|transfer|storage_size|c_loc|c_f_pointer|c_associated|move_alloc|random_number|random_seed|cpu_time|system_clock|date_and_time|selected_int_kind|selected_real_kind|achar|iachar|char|ichar|new_line|is_contiguous|findloc|isnan|ieee_is_nan)$"))

; "character" is listed as a builtin function upstream; in declarations it is a type
((intrinsic_type
  "character" @type.builtin)
  (#set! priority 101))
