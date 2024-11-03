type lexeme = string
type line = int

type literal = (* FloatLiteral of float  *)
  | StringLiteral of string

type token =
  | Token of lexeme * line
  | TokenWithLiteral of literal * lexeme * line

let hadError = ref false
let hadRuntimeError = ref false

let error line message =
  hadError := true;
  Printf.eprintf "[line %d] Error: %s\n" line message

let single_chars =
  [ '('; ')'; '{'; '}'; ','; '.'; '-'; '+'; ';'; '*'; '='; '!'; '<'; '>'; '/' ]

let stringify_token_lexeme token_kind =
  match token_kind with
  | "(" -> "LEFT_PAREN"
  | ")" -> "RIGHT_PAREN"
  | "{" -> "LEFT_BRACE"
  | "}" -> "RIGHT_BRACE"
  | "," -> "COMMA"
  | "." -> "DOT"
  | "-" -> "MINUS"
  | "+" -> "PLUS"
  | ";" -> "SEMICOLON"
  | "/" -> "SLASH"
  | "*" -> "STAR"
  | "=" -> "EQUAL"
  | "==" -> "EQUAL_EQUAL"
  | "!=" -> "BANG_EQUAL"
  | "!" -> "BANG"
  | "<" -> "LESS"
  | "<=" -> "LESS_EQUAL"
  | ">" -> "GREATER"
  | ">=" -> "GREATER_EQUAL"
  | string_literal when String.starts_with ~prefix:"\"" string_literal ->
      "STRING"
  | "" -> "EOF"
  | _ -> "UNKNOWN"

let stringify token =
  match token with
  | Token (lexeme, _) ->
      Printf.sprintf "%s %s %s" (stringify_token_lexeme lexeme) lexeme "null"
  | TokenWithLiteral (literal, lexeme, _) ->
      Printf.sprintf "%s %s %s"
        (stringify_token_lexeme lexeme)
        lexeme
        (match literal with
        (* | FloatLiteral f -> Float.to_string f *)
        | StringLiteral s -> s)

let rec tokenize chars tokens line =
  match chars with
  | [] -> List.rev (Token ("", line) :: tokens)
  | '"' :: rest ->
      let rec consume_str_literal c literal =
        match c with
        | [] -> None
        | '"' :: after_str ->
            Some
              ( StringLiteral
                  (literal |> List.rev |> List.to_seq |> String.of_seq),
                after_str )
        | str_char :: after_char ->
            consume_str_literal after_char (str_char :: literal)
      in

      let result =
        match consume_str_literal rest [] with
        | Some (StringLiteral str_literal, after_str) ->
            tokenize after_str
              (TokenWithLiteral
                 ( StringLiteral str_literal,
                   Printf.sprintf "\"%s\"" str_literal,
                   line )
              :: tokens)
              line
        | _ ->
            error line "Unterminated string.";
            tokenize [] tokens line
      in
      result
  | ' ' :: rest | '\r' :: rest | '\t' :: rest -> tokenize rest tokens line
  | '\n' :: rest -> tokenize rest tokens (line + 1)
  | '/' :: '/' :: rest ->
      let rec consume_comment c =
        match c with [] | '\n' :: _ -> c | _ :: rest -> consume_comment rest
      in
      tokenize (consume_comment rest) tokens line
  | '<' :: '=' :: rest -> tokenize rest (Token ("<=", 0) :: tokens) line
  | '>' :: '=' :: rest -> tokenize rest (Token (">=", 0) :: tokens) line
  | '!' :: '=' :: rest -> tokenize rest (Token ("!=", 0) :: tokens) line
  | '=' :: '=' :: rest -> tokenize rest (Token ("==", 0) :: tokens) line
  | char :: rest when List.exists (fun c -> c = char) single_chars ->
      tokenize rest (Token (String.make 1 char, 0) :: tokens) line
  | unknown_char :: rest ->
      error line (Printf.sprintf "Unexpected character: %c" unknown_char);
      tokenize rest tokens line

let () =
  if Array.length Sys.argv < 3 then (
    Printf.eprintf "Usage: ./your_program.sh tokenize <filename>\n";
    exit 1);

  let command = Sys.argv.(1) in
  let filename = Sys.argv.(2) in

  if command <> "tokenize" then (
    Printf.eprintf "Unknown command: %s\n" command;
    exit 1);

  let file_contents = In_channel.with_open_text filename In_channel.input_all in
  let chars = file_contents |> String.to_seq |> List.of_seq in
  let tokens = tokenize chars [] 1 in
  List.iter (fun x -> x |> stringify |> print_endline) tokens;
  if !hadError then exit 65;
  if !hadRuntimeError then exit 70;
  ()
