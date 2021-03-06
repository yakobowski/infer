(*
 * Copyright (c) 2018-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

(** Mset - Set with integer (positive, negative, or zero) multiplicity for
    each element *)

open Base

type ('elt, 'cmp) t = ('elt, Z.t, 'cmp) Map.t

module M (Elt : sig
  type t
  type comparator_witness
end) =
struct
  type nonrec t = (Elt.t, Elt.comparator_witness) t
end

module type Sexp_of_m = sig
  type t [@@deriving sexp_of]
end

module type M_of_sexp = sig
  type t [@@deriving of_sexp]

  include Comparator.S with type t := t
end

module type Compare_m = sig end
module type Hash_fold_m = Hasher.S

let sexp_of_z z = Sexp.Atom (Z.to_string z)
let z_of_sexp = function Sexp.Atom s -> Z.of_string s | _ -> assert false
let hash_fold_z state z = Hash.fold_int state (Z.hash z)

let sexp_of_m__t (type elt) (module Elt : Sexp_of_m with type t = elt) t =
  Map.sexp_of_m__t (module Elt) sexp_of_z t

let m__t_of_sexp (type elt cmp)
    (module Elt : M_of_sexp
      with type t = elt and type comparator_witness = cmp) sexp =
  Map.m__t_of_sexp (module Elt) z_of_sexp sexp

let compare_m__t (module Elt : Compare_m) = Map.compare_direct Z.compare

let hash_fold_m__t (type elt) (module Elt : Hash_fold_m with type t = elt)
    state =
  Map.hash_fold_m__t (module Elt) hash_fold_z state

let hash_m__t (type elt) (module Elt : Hash_fold_m with type t = elt) =
  Hash.of_fold (hash_fold_m__t (module Elt))

type ('elt, 'cmp) comparator =
  (module Comparator.S with type t = 'elt and type comparator_witness = 'cmp)

let empty cmp = Map.empty cmp
let if_nz z = if Z.equal Z.zero z then None else Some z

let add m x i =
  Map.change m x ~f:(function Some j -> if_nz Z.(i + j) | None -> if_nz i)

let remove m x = Map.remove m x

let union m n =
  Map.merge m n ~f:(fun ~key:_ -> function
    | `Both (i, j) -> if_nz Z.(i + j) | `Left i | `Right i -> Some i )

let length m = Map.length m
let count m x = match Map.find m x with Some z -> z | None -> Z.zero

let count_and_remove m x =
  let found = ref Z.zero in
  let m =
    Map.change m x ~f:(function
      | None -> None
      | Some i ->
          found := i ;
          None )
  in
  if Z.equal !found Z.zero then None else Some (!found, m)

let min_elt = Map.min_elt
let fold m ~f ~init = Map.fold m ~f:(fun ~key ~data s -> f key data s) ~init

let map m ~f =
  fold m ~init:m ~f:(fun x i m ->
      let x', i' = f x i in
      if phys_equal x' x then
        if Z.equal i' i then m else Map.set m ~key:x ~data:i'
      else add (Map.remove m x) x' i' )

let fold_map m ~f ~init:s =
  fold m ~init:(m, s) ~f:(fun x i (m, s) ->
      let x', i', s = f x i s in
      if phys_equal x' x then
        if Z.equal i' i then (m, s) else (Map.set m ~key:x ~data:i', s)
      else (add (Map.remove m x) x' i', s) )

let for_all m ~f = Map.for_alli m ~f:(fun ~key ~data -> f key data)
let map_counts m ~f = Map.mapi m ~f:(fun ~key ~data -> f key data)
let iter m ~f = Map.iteri m ~f:(fun ~key ~data -> f key data)
let to_list m = Map.to_alist m
