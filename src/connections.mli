(** Need to store active connections in order to be able to send data to them from other users *)

(** [add t j f] adds [j] and [f] to [t] and returns a new [t] with them added. [f] is the push function to the stream for that user *)
val add : Jid.Full.t -> (Actions.t option -> unit) -> unit Lwt.t

(** [find t j] returns the push function associated with the [j] in the connections map if it is present *)
val find : Jid.Full.t -> (Actions.t option -> unit) option Lwt.t

(** [find_all j] returns the list of jid * actions_push function pairs which correspond to the same bare jid as [j] *)
val find_all : Jid.Bare.t -> (Jid.Full.t * (Actions.t option -> unit)) list Lwt.t

(** [remove t j] removes the jid [j] entry from the table if present *)
val remove : Jid.Full.t -> unit Lwt.t

val to_string : unit -> string Lwt.t
val clear : unit -> unit Lwt.t
