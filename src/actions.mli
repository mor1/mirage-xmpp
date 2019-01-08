(** The module for actions generated by the state machine *)

type handler_actions = RESET_PARSER

val handler_actions_to_string : handler_actions -> string

type error_type =
  | Auth
  | Cancel
  | Continue
  | Modify
  | Wait

val error_type_to_string : error_type -> string

(** The type of actions, examples for now *)
type t =
  | SEND_STREAM_HEADER
  | SEND_STREAM_FEATURES_SASL
  | SEND_SASL_SUCCESS
  | SEND_STREAM_FEATURES
  | SERVER_GEN_RESOURCE_IDENTIFIER of string
  | SESSION_START_SUCCESS of string
  | CLOSE
  | ERROR of string
  | SET_JID of string
  | SET_JID_RESOURCE of {id : string; resource : string}
  | GET_ROSTER of string
  | SET_ROSTER of
      { id : string
      ; target : Jid.t
      ; handle : string
      ; subscription : Rosters.subscription
      ; groups : string list }
  | PUSH_ROSTER of
      { jid : Jid.t option
      ; target : Jid.t
      ; handle : string
      ; subscription : Rosters.subscription
      ; groups : string list }
  | ADD_TO_CONNECTIONS
  | REMOVE_FROM_CONNECTIONS
  | SUBSCRIPTION_REQUEST of {id : string; ato : Jid.t}
  | UPDATE_PRESENCE of Rosters.availability
  | SEND_PRESENCE_UPDATE of Jid.t
  | IQ_ERROR of {error_type : error_type; error_tag : string; id : string}
  | MESSAGE of {ato : Jid.t; message : Xml.t}

(** [to_string t] takes an action and returns its string representation *)
val to_string : t -> string
