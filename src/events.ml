type t =
  | STREAM_HEADER of Xml.tag
  | RESOURCE_BIND_SERVER_GEN of string
  | RESOURCE_BIND_CLIENT_GEN of string * string
  | STREAM_CLOSE
  | ERROR of string
  | ROSTER_GET of string * Jid.t
  | ROSTER_SET of string * Jid.t * Jid.t * string * bool * string list

let to_string = function
  | STREAM_HEADER tag -> "STREAM_HEADER: " ^ Xml.tag_to_string ~empty:true tag
  | RESOURCE_BIND_SERVER_GEN _id -> "RESOURCE_BIND_SERVER_GEN: id"
  | RESOURCE_BIND_CLIENT_GEN (id, jid) ->
    "RESOURCE_BIND_CLIENT_GEN: id=" ^ id ^ " jid=" ^ jid
  | STREAM_CLOSE -> "STREAM_CLOSE"
  | ERROR s -> "ERROR: " ^ s
  | ROSTER_GET (id, from) -> "ROSTER_GET: id=" ^ id ^ " from=" ^ Jid.to_string from
  | ROSTER_SET (id, from, target, handle, subscribed, groups) ->
    "ROSTER_SET: id="
    ^ id
    ^ " from="
    ^ Jid.to_string from
    ^ " target="
    ^ Jid.to_string target
    ^ " handle="
    ^ handle
    ^ " subscribed="
    ^ string_of_bool subscribed
    ^ " groups=["
    ^ String.concat " " groups
    ^ "]"
;;

let not_implemented = ERROR "not implemented"

let lift_iq = function
  | Xml.Element (((_prefix, _name), attributes), children) ->
    (match Stanza.get_type attributes with
    | "set" ->
      (match children with
      | [Xml.Element (((_p, "bind"), _attrs), [])] ->
        (* resource bind with server-generated resource identifier (7.6) *)
        RESOURCE_BIND_SERVER_GEN (Stanza.get_id attributes)
      | [Xml.Element (((_p, "bind"), _attrs), [child])] ->
        (match child with
        | Xml.Element (((_, "resource"), []), [Xml.Text t]) ->
          RESOURCE_BIND_CLIENT_GEN (Stanza.get_id attributes, t)
        | _ -> not_implemented)
      | [ Xml.Element
            (((_, "query"), _), [Xml.Element (((_, "item"), attrs), group_elements)]) ]
      ->
        let groups =
          List.map
            (fun element ->
              match element with
              | Xml.Element (((_, "group"), _), [Xml.Text group]) -> group
              | _ -> assert false )
            group_elements
        in
        let jid = Stanza.get_jid attrs in
        let handle = Stanza.get_name attrs in
        ROSTER_SET
          ( Stanza.get_id attributes
          , Stanza.get_from attributes
          , jid
          , handle
          , false
          , groups )
      | _ -> not_implemented)
    | "get" ->
      (match children with
      | [Xml.Element (((_, "query"), _), [])] ->
        (* roster get query *)
        ROSTER_GET (Stanza.get_id attributes, Stanza.get_from attributes)
      | _ -> not_implemented)
    | _ -> not_implemented)
  | Xml.Text _t -> not_implemented
;;

let lift parse_result =
  let open Parser in
  match parse_result with
  | Stanza stanza ->
    (match stanza with
    | Stanza.Iq element -> lift_iq element
    | Stanza.Presence (Element (((_prefix, _name), _attributes), _children) as _xml) ->
      not_implemented
    | Stanza.Message (Element (((_prefix, _name), _attributes), _children) as _xml) ->
      not_implemented
    | _ -> ERROR "Not expecing text elements")
  | Stream_Element stream_element ->
    (match stream_element with
    | Header tag -> STREAM_HEADER tag
    | Features -> not_implemented
    | Error -> not_implemented
    | Close -> STREAM_CLOSE)
  | Error e -> ERROR e
;;

let%expect_test "lift error gives error" =
  let event = lift (Error "some error") in
  print_endline (to_string event);
  [%expect {| ERROR: some error |}]
;;

let%expect_test "iq get" =
  let event =
    lift
      (Stanza
         (Stanza.Iq
            (Element
               ( ( ("", "iq")
                 , [ "", Xml.From (Jid.of_string "juliet@capulet.com/balcony")
                   ; "", Xml.Id "h83vxa4c"
                   ; "", Xml.Type "get" ] )
               , [Xml.Element ((("", "query"), []), [])] ))))
  in
  print_endline (to_string event);
  [%expect {| ROSTER_GET: id=h83vxa4c from=juliet@capulet.com/balcony |}]
;;

let%expect_test "iq set" =
  let event =
    lift
      (Stanza
         (Stanza.Iq
            (Element
               ( (("", "iq"), ["", Xml.Id "l3b1vs75"; "", Xml.Type "set"])
               , [Xml.Element ((("", "bind"), []), [])] ))))
  in
  print_endline (to_string event);
  [%expect {| RESOURCE_BIND_SERVER_GEN: id |}]
;;

let%expect_test "roster get" =
  let event =
    lift
      (Stanza
         (Stanza.Iq
            (Element
               ( ( ("", "iq")
                 , [ "", Xml.From (Jid.of_string "juliet@example.com/balony")
                   ; "", Xml.Id "bv1bs71f"
                   ; "", Xml.Type "get" ] )
               , [Xml.Element ((("", "query"), ["", Xml.Xmlns "jabber:iq:roster"]), [])]
               ))))
  in
  print_endline (to_string event);
  [%expect {| ROSTER_GET: id=bv1bs71f from=juliet@example.com/balony |}]
;;

let%expect_test "roster set" =
  let event =
    lift
      (Stanza
         (Stanza.Iq
            (Element
               ( ( ("", "iq")
                 , [ "", Xml.From (Jid.of_string "juliet@example.com/balony")
                   ; "", Xml.Id "rs1"
                   ; "", Xml.Type "set" ] )
               , [ Xml.Element
                     ( (("", "query"), ["", Xml.Xmlns "jabber:iq:roster"])
                     , [ Xml.Element
                           ( ( ("", "item")
                             , [ "", Xml.Jid (Jid.of_string "nurse@example.com")
                               ; "", Xml.Name "Nurse" ] )
                           , [] ) ] ) ] ))))
  in
  print_endline (to_string event);
  [%expect
    {| ROSTER_SET: id=rs1 from=juliet@example.com/balony target=nurse@example.com handle=Nurse subscribed=false groups=[] |}]
;;
