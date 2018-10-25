open Lwt.Infix
open Core_kernel

module Main (S : Mirage_stack_lwt.V4) = struct
  let write_string flow s =
    let b = Cstruct.of_string s in
    S.TCPV4.write flow b
    >>= function
    | Ok () -> Lwt.return_unit
    | Error e ->
      Logs.warn (fun f ->
          f "Error occurred from writing to connection: %a" S.TCPV4.pp_write_error e );
      Lwt.return_unit
  ;;

  let read flow pushf =
    let rec aux () =
      S.TCPV4.read flow
      >>= function
      | Ok `Eof -> Lwt.return_unit
      | Error _ -> Lwt.return_unit
      | Ok (`Data b) ->
        let s = Cstruct.to_string b in
        String.iter ~f:(fun c -> pushf (Some c)) s;
        aux ()
    in
    aux ()
  ;;

  let parse_xml stream =
    let stream = Markup_lwt.lwt_stream stream in
    let parser =
      Markup_lwt.parse_xml
        ~report:(fun l e ->
          Logs.warn (fun f ->
              f "Error occurred during parsing: %s" (Markup.Error.to_string e) );
          Lwt.return_unit )
        stream
    in
    let signals = Markup.signals parser in
    let rec pull_signal depth =
      Markup_lwt.next signals
      >>= function
      | Some signal ->
        (match signal with
        | `Start_element ((uri, local), attrs) ->
          Logs.debug (fun f -> f "Start element received: %s:%s" uri local);
          pull_signal (depth + 1)
        | `End_element ->
          Logs.debug (fun f -> f "End element received");
          if depth = 1 then Lwt.return_unit else pull_signal (depth - 1)
        | `Text strings ->
          let stripped_strings = List.map ~f:(fun s -> String.strip s) strings in
          let non_empty_strings =
            List.filter ~f:(fun s -> String.strip s <> "") stripped_strings
          in
          List.iter
            ~f:(fun s -> Logs.debug (fun f -> f "Found text: %s" s))
            non_empty_strings;
          pull_signal depth
        | _ ->
          Logs.debug (fun f -> f "signal received! %s" (Markup.signal_to_string signal));
          pull_signal depth)
      | None ->
        Logs.debug (fun f -> f "None signal received");
        Lwt.return_unit
    in
    pull_signal 0
  ;;

  let on_connect flow =
    let stream, pushf = Lwt_stream.create () in
    Lwt.async (fun () -> read flow pushf);
    parse_xml stream
    >>= fun () ->
    Logs.debug (fun f -> f "Closing the connection");
    S.TCPV4.close flow
  ;;

  let start s =
    let port = Key_gen.port () in
    S.listen_tcpv4 s ~port on_connect;
    S.listen s
  ;;
end
