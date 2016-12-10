open Core.Std
open Nocrypto

open Lwt
open Cohttp
open Cohttp_lwt_unix

module Header = Cohttp.Header
                  
let mb_tapi_id = Sys.getenv_exn "MB_TAPI_ID";;
let mb_tapi_secret = Sys.getenv_exn "MB_TAPI_SECRET";;

let request_host = "https://www.mercadobitcoin.net"
let request_path = "/tapi/v3/"
                     
let c_of_str = Cstruct.of_string

let c_to_str = Cstruct.to_string

let sign ~key msg =
  let key = c_of_str key in
  let msg = c_of_str msg in
  Hash.SHA512.hmac ~key msg
  |> Hex.of_cstruct
  |> function
    `Hex str -> str

let nonce () =
  Time.now ()
  |> Time.to_epoch
  |> sprintf "%.0f"
  |> String.filter ~f:begin function
    | ',' | '.' -> false
    | _ -> true end

let make_params mb_method =
  [ "tapi_nonce", [nonce ()]
  ; "tapi_method", [mb_method]]

let encoded_params mb_method =
  Uri.encoded_of_query (make_params mb_method)

let calculate_tapi_mac enc_params =
  let msg = (request_path ^ "?" ^ enc_params) in
  let () = print_endline msg in 
  sign ~key:mb_tapi_secret msg
      
let tapi_header enc_params =
  [ "TAPI-ID", mb_tapi_id
  ; "TAPI-MAC", calculate_tapi_mac enc_params]

let request mb_method =
  let uri = Uri.of_string @@ request_host ^ request_path in
  let body = encoded_params mb_method in 
  let headers_list =
    let length = String.length body in
    tapi_header body @
    [ "Content-Type" , "application/x-www-form-urlencoded"
    ; "Content-length", Int.to_string (length)] in
  let headers = Header.of_list headers_list in 
  print_endline @@ Header.to_string headers;
  print_endline @@ (Uri.to_string uri);
  print_endline @@ body;

  Client.post ~headers uri
    ~body:(Cohttp_lwt_body.of_string body)

module Test = struct
  let tapi_secret="1ebda7d457ece1330dff1c9e04cd62c4e02d1835968ff89d2fb2339f06f73028"
  let tapi_method = "/tapi/v3/?tapi_method=list_orders&tapi_nonce=1"
  let tapi_mac_result=
    "7f59ea8749ba596d5c23fa242a531746b918e5e61c9f6c8663a699736db503980f3a507ff7e2ef1336f7888d684a06c9a460d18290e7b738a61d03e25ffdeb76"
  let test () =
    sign ~key:tapi_secret tapi_method |>
    (=) tapi_mac_result
end
