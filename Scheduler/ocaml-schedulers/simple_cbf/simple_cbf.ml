(*                                                          *)
(*   A simple proto of Conservative Backfilling scheduler   *)
(*                                                          *)

(*

Todo:
- take code from Lionel's one
- module 
- iolib
- matching !!
- reservation
- gantt diagram coupling

- others oar scheduler functionality (out-of-order):
 * support for different type of resource
 * resource hierarchies
 * besteffort
 * fairesharing
 * resource state (
 * modalable
 * multi-resource type
 * timesharing
 * idempotent
 * other backfilling algorithms
 * generic fairshare
 * Postgresl

Done:
8) split_slots_prev_scheduled_jobs 
7) ints2intervals
6) preliminar simple-cbf-oar (base files) 
5) preliminary test schedule_jobs
2) Ressource Assignement
3) Split Contiguous Slots
4) inter_intervals [x1] [y1] [] 0 -> inter_intervals [x1] [y1] 

Other:
1) A better inter_intervals_x functions need to be more elegant ???




2.5) sub_intervals
1) Test find_first_suitable_contiguous_slots 
*)

open Types
open Interval
open Int64

type slot = {
	time_s : time_t;
	time_e : time_t;
	nb_free_res : int;
	set_of_res : set_of_resources;
}

let slot_to_string slot = let itv2str itv = Printf.sprintf "[%d,%d]" itv.b itv.e in 
  (Printf.sprintf "time_s %s, time_e: %s, nb_free_res: %d\n" 
    (to_string slot.time_s) (to_string slot.time_e) slot.nb_free_res) ^
  (String.concat ", " (List.map itv2str slot.set_of_res))

(*******************************************************)
(* find_first_contiguous_slots_time *)
(* where job can fit in time        *)

(* provides contiguous_slots which fit job_walltime and remain slots list *)

let find_contiguous_slots_time slot_l job =

	let rec find_ctg_slots slots ctg_slots prev_slots = match slots with
		| s::n when (s.time_e >= (add (add job.time_b job.walltime) minus_one)) -> (ctg_slots @ [s], prev_slots , n)
		| s::n when ((add s.time_e one) <> (List.hd n).time_s) -> 
			 job.time_b <- (List.hd n).time_s;
			 find_ctg_slots n [] (prev_slots @ ctg_slots @ [s])
		| s::n -> find_ctg_slots n (ctg_slots @ [s]) prev_slots
 		| _ -> failwith "Not contiguous job is too long (BUG??)";

		in let next_slot_time_s = (List.hd slot_l).time_s in
			job.time_b <- next_slot_time_s;
	  	find_ctg_slots slot_l [] [];;

(*
let s0 =  {time_s = 0; time_e = 4; nb_free_res = 1; set_of_res = []};;
let s1 =  {time_s = 5; time_e = 10; nb_free_res = 2; set_of_res = []};;
let s2 =  {time_s = 12; time_e = 10; nb_free_res = 2; set_of_res = []};;
let s3 =  {time_s = 20; time_e = 50; nb_free_res = 3; set_of_res = []};;
let s5 =  {time_s = 60; time_e = 70; nb_free_res = 3; set_of_res = []};;

let j1 = { time_b = 0; walltime = 3; nb_res = 5; set_of_rs = []};;
let j2 = { time_b = 0; walltime = 5; nb_res = 5; set_of_rs = []};;
let j3 = { time_b = 0; walltime = 6; nb_res = 5; set_of_rs = []};;
let j4 = { time_b = 0; walltime = 8; nb_res = 5; set_of_rs = []};;
let j5 = { time_b = 0; walltime = 20; nb_res = 5; set_of_rs = []};;


find_contiguous_slots_time [s0] j1 ;; [s0] [] []
find_contiguous_slots_time [s0;s1] j1 ;;  [s0] [] [s1]
find_contiguous_slots_time [s0;s1] j3 ;; [s0;s1] [] []
find_contiguous_slots_time [s0;s3] j5 ;; [s3] [s0] []
find_contiguous_slots_time [s0;s1;s3;s5] j5 ;; [s3] [s0;s1] [s5]


find_contiguous_slots_time [s0;s1;s2] [] []  (s0.time_s-1) j1;;
find_contiguous_slots_time [s0;s1;s2;s3;s5] [] []  (s0.time_s-1) j5;;(*Exception: Failure "hd". TODO ??? *)
*)


(* Evaluate the intersection  of set of resources intervals of a contiguous list of slots *)
let test_inter_slots_nb_res contiguous_slots nb_res = let rec iter_slots s_l s_of_res nb_free_res = match s_l with
	| _ when nb_free_res < nb_res -> (false, []);
	| s::n -> let inter_itv = inter_intervals s.set_of_res s_of_res [] 0 in iter_slots n (fst inter_itv) (snd inter_itv)
	| [] -> (true, s_of_res)
	in iter_slots (List.tl contiguous_slots) (List.hd contiguous_slots).set_of_res (List.hd contiguous_slots).nb_free_res;;

(*
let s0 =  {time_s = 0; time_e = 4; nb_free_res = 40; set_of_res = [{b = 1; e = 40}]};;
let s1 =  {time_s = 5; time_e = 10; nb_free_res = 20; set_of_res = [{b = 11; e = 20};{b = 31; e = 40}]};;
let s4 =  {time_s = 11; time_e = 14; nb_free_res = 25; set_of_res = [{b = 11; e = 35}]};;

test_inter_slots_nb_res [s0;s1;s4] 10;; (* (true, [{b = 11; e = 20}; {b = 31; e = 35}]) *)
test_inter_slots_nb_res [s0;s1;s4] 16;; (* (false, []) *)
*)

(* find_first_suitable_contiguous_slots for job
let rec find_first_suitable_contiguous_slots slot_l job = 
	let next_ctg_time_slot = find_contiguous_slots_time slot_l [] ((List.hd slot_l).time_s-1) job in
		let test_inter_slots = test_inter_slots_nb_res (fst next_ctg_time_slot) job.nb_res in 
			if (fst test_inter_slots) then 
				snd test_inter_slots
		 	else
				find_first_suitable_contiguous_slots (List.tl (fst next_ctg_time_slot) @  (snd next_ctg_time_slot)) job;;
*)
(* find_first_suitable_contiguous_slots for job *) 

let find_first_suitable_contiguous_slots slots j =
	let rec find_suitable_contiguous_slots slot_l pre_slots job = 
		let (next_ctg_time_slot, prev_slots, remain_slots) = find_contiguous_slots_time slot_l job in
			let (test_inter_slots, s_of_res) = test_inter_slots_nb_res next_ctg_time_slot job.nb_res in 
				if test_inter_slots then 
					(s_of_res, next_ctg_time_slot, (pre_slots @ prev_slots), remain_slots)
		 		else
					find_suitable_contiguous_slots (List.tl next_ctg_time_slot @ remain_slots) (pre_slots @ prev_slots @ [List.hd next_ctg_time_slot]) job
		in
			find_suitable_contiguous_slots slots [] j;;


(*

let s0 =  {time_s = 0; time_e = 4; nb_free_res = 40; set_of_res = [{b = 1; e = 40}]};;
let s1 =  {time_s = 5; time_e = 10; nb_free_res = 20; set_of_res = [{b = 11; e = 20};{b = 31; e = 40}]};;
let s4 =  {time_s = 11; time_e = 14; nb_free_res = 25; set_of_res = [{b = 11; e = 35}]};;
let s5 =   {time_s = 21; time_e = 30; nb_free_res = 15; set_of_res = [{b = 21; e = 35}]};;

let j1 = { time_b = 0; walltime = 3; nb_res = 5; set_of_rs = []};;
let j2  = { time_b = 0; walltime = 12; nb_res = 5; set_of_rs = []};;
let j3  =  { time_b = 0; walltime = 3; nb_res = 22; set_of_rs = []};;


find_first_suitable_contiguous_slots [s0;s1;s4] j1 ;; (* [{b = 1; e = 40}], [s0], [], [s1;s4] *) 

find_first_suitable_contiguous_slots [s0;s1;s4] j2 ;; (* ([{b = 11; e = 20}; {b = 31; e = 35}], [s0;s1;s4], [], []) *)
find_first_suitable_contiguous_slots [s1;s4;s5] j3 ;; (* [{b = 11; e = 35}], [s4], [s1], [s5] *)

*)

(*******************************************************)
(* split slot accordingly with job resource assignment *)
(* new slot A + B + C (A, B and C can be null)         *)

(*
 ------
|A|B|C|
|A|J|C|
|A|B|C|
 ------
*)

(* TODO *)

(* generate A slot *) (* slot before job's begin *)
let slot_before_job_begin slot job = {
	time_s = slot.time_s;
	time_e = add job.time_b minus_one;
	nb_free_res = slot.nb_free_res;
	set_of_res = slot.set_of_res;
};;

(* generate B slot *) 
let slot_during_job slot job = {
		time_s = max job.time_b slot.time_s;
		time_e = min (add (add job.time_b  job.walltime) minus_one) slot.time_e ;
		nb_free_res = slot.nb_free_res-job.nb_res;
		set_of_res = sub_intervals slot.set_of_res job.set_of_rs;
	}
;;

(* generate C slot *) (* slot after job's end *)

let slot_after_job_end slot job = {
	time_s = add job.time_b job.walltime;
	time_e = slot.time_e  ;
	nb_free_res = slot.nb_free_res;
	set_of_res = slot.set_of_res;
};;


let split_slots slots job = 
	let split_slot slt = 
		if job.time_b > slt.time_s then (* AAA *)
			if  (add (add job.time_b job.walltime) minus_one) > slt.time_e then
					if slt.nb_free_res > job.nb_res then
					 (* A+B *)
						(slot_before_job_begin slt job) :: [(slot_during_job slt job)]
					else
					 (* A *)
						[slot_before_job_begin slt job]
			else
					if slt.nb_free_res > job.nb_res then
				 		(* A+B+C *)
						(slot_before_job_begin slt job) :: (slot_during_job slt job) :: [(slot_after_job_end slt job)]
					else
						(slot_before_job_begin slt job) :: [(slot_after_job_end slt job)]
		else
			if (add (add job.time_b  job.walltime) minus_one) >= slt.time_e then
				if slt.nb_free_res > job.nb_res then
				 (* B *)
					[slot_during_job slt job]
				else
					[]
			else	
				if slt.nb_free_res > job.nb_res then
				 	(* B+C *) 
					( slot_during_job slt job) :: [(slot_after_job_end slt job )]
				else
					[slot_after_job_end slt job]	
	in List.flatten (List.map (fun slot -> split_slot slot ) slots) ;;



(* test split_slots 
let s0 =  {time_s = 0; time_e = 20; nb_free_res = 40; set_of_res = [{b = 1; e = 40}]};;
let s1 =  {time_s = 21; time_e = 30; nb_free_res = 20; set_of_res = [{b = 11; e = 20};{b = 31; e = 40}]};;
let s2 =  {time_s = 31; time_e = 40; nb_free_res = 25; set_of_res = [{b = 11; e = 35}]};;
let s11=  {time_s = 21; time_e = 30; nb_free_res = 6; set_of_res = [{b = 15; e = 20}]};;



let j0 = { time_b = 5; walltime = 10; nb_res = 6; set_of_rs = [{b = 15; e = 20}]};;
let j1 = { time_b = 0; walltime = 15; nb_res = 6; set_of_rs = [{b = 15; e = 20}]};;
let j2 = { time_b = 0; walltime = 21; nb_res = 6; set_of_rs = [{b = 15; e = 20}]};;
let j3 = { time_b = 5; walltime = 35; nb_res = 6; set_of_rs = [{b = 15; e = 20}]};;


split_slots [s0] j0;;
[{time_s = 0; time_e = 4; nb_free_res = 40; set_of_res = [{b = 1; e = 40}]};
  {time_s = 5; time_e = 14; nb_free_res = 34; set_of_res = [{b = 1; e = 14}; {b = 21; e = 40}]};
  {time_s = 15; time_e = 20; nb_free_res = 40; set_of_res = [{b = 1; e = 40}]}]

split_slots [s0] j1;;
[{time_s = 0; time_e = 14; nb_free_res = 34; set_of_res = [{b = 1; e = 14}; {b = 21; e = 40}]};
  {time_s = 15; time_e = 20; nb_free_res = 40; set_of_res = [{b = 1; e = 40}]}]


split_slots [s0] j2;;
[{time_s = 0; time_e = 20; nb_free_res = 34; set_of_res = [{b = 1; e = 14}; {b = 21; e = 40}]}]


split_slots [s0;s1;s2] j3;;
[{time_s = 0; time_e = 4; nb_free_res = 40; set_of_res = [{b = 1; e = 40}]};
 {time_s = 5; time_e = 20; nb_free_res = 34; set_of_res = [{b = 1; e = 14}; {b = 21; e = 40}]};

 {time_s = 21; time_e = 30; nb_free_res = 14; set_of_res = [{b = 11; e = 14}; {b = 31; e = 40}]};

 {time_s = 31; time_e = 39; nb_free_res = 19; set_of_res = [{b = 11; e = 14}; {b = 21; e = 35}]};
 {time_s = 40; time_e = 40; nb_free_res = 25; set_of_res = [{b = 11; e = 35}]}]

split_slots [s0;s11;s2] j3;;
[{time_s = 0; time_e = 4; nb_free_res = 40; set_of_res = [{b = 1; e = 40}]};
 {time_s = 5; time_e = 20; nb_free_res = 34; set_of_res = [{b = 1; e = 14}; {b = 21; e = 40}]};

 {time_s = 31; time_e = 39; nb_free_res = 19; set_of_res = [{b = 11; e = 14}; {b = 21; e = 35}]};
 {time_s = 40; time_e = 40; nb_free_res = 25;
*)


let resources_assign_job nb_res itv_l = 
	let rec res_assign_job r itv_l res_itv_l = match itv_l with
	| x::n -> if (x.e-x.b+1) >= r then 
		 	List.rev ({b = x.b; e = x.b + r-1}::res_itv_l)
		else
			res_assign_job (r -x.e + x.b - 1) n (x::res_itv_l)
	| _ -> failwith "Not enougth resources (BUG!)"
	in
		res_assign_job nb_res itv_l [];;
(*
let x1 = {b = 11; e = 20};; 
let y1 =  {b = 1; e = 5};; 
resources_assign_job 1 [x1];; (* [{b = 11; e = 11}] *)
resources_assign_job 10 [x1];; (* [x1] *)
resources_assign_job 12 [x1];;  (* Exception: Failure "Not enougth resources (BUG!)". *)
resources_assign_job 12 [y1;x1];; (* [{b = 1; e = 5}; {b = 11; e = 17}] *)
*)


(* to debug !! *)
let assign_resources_job_split_slots job slots = 
	let (itv_l, ctg_slots, prev_slots, remain_slots) = find_first_suitable_contiguous_slots slots job in
		let resource_assigned	= resources_assign_job job.nb_res itv_l in
				job.set_of_rs <- resource_assigned;
			 (job, prev_slots @ (split_slots ctg_slots job) @ remain_slots);;

let rec schedule_jobs jobs slots = 
	let rec assign_res_jobs jobs scheduled_jobs slot_list = match jobs with
		| [] -> List.rev scheduled_jobs
		| j::n -> let (job, updated_slots ) = assign_resources_job_split_slots j slot_list in assign_res_jobs n  (job::scheduled_jobs) updated_slots
	in assign_res_jobs jobs [] slots;;
	 
let slot_max nb_res = {time_s = zero; time_e = max_int; nb_free_res = nb_res; set_of_res = [{b = 1; e = nb_res}]};;

(* function insert previously scheduled job in slots *)
(* job must be sorted by start_time *)
let split_slots_prev_scheduled_jobs slots jobs =

  let rec find_first_slot left_slots right_slots job = match right_slots with
    | x::n  when ((x.time_s > job.time_b) || ((x.time_s <= job.time_b) && (job.time_b <= x.time_e))) -> (left_slots,x,n) 
    | x::n -> find_first_slot (left_slots @ [x]) n job 
    | [] -> failwith "Argl cannot failed here"

  in

  let rec find_slots_aux encompass_slots r_slots job = match r_slots with
    (* find timed slots *)
    | x::n when (x.time_e >  (add job.time_b job.walltime)) -> (encompass_slots @ [x],n) 
    | x::n -> find_slots_aux (encompass_slots @ [x]) n job
    | [] -> failwith "Argl cannot failed here"
   in

  let find_slots_encompass first_slot right_slots job =
    if (first_slot.time_e >  (add job.time_b job.walltime)) then
      ([first_slot],right_slots)
    else find_slots_aux [first_slot] right_slots job

    in

      let rec split_slots_next_job prev_slots remain_slots job_l = match job_l with
        | [] -> prev_slots @ remain_slots
        | x::n -> let (l_slots, first_slot, r_slots) = find_first_slot prev_slots remain_slots x in
                  let (encompass_slots, ri_slots) =  find_slots_encompass first_slot r_slots x in
                  let splitted_slots =  split_slots encompass_slots x in 
                    split_slots_next_job l_slots (splitted_slots @ ri_slots) n 
     in 
        split_slots_next_job [] slots jobs

(*
let j0 =  { time_b = 0; walltime = 5; nb_res = 5; set_of_rs = []};;
let j1 =  { time_b = 0; walltime = 5; nb_res = 100; set_of_rs = []};;
let j2 =  { time_b = 0; walltime = 5; nb_res = 5; set_of_rs = []};;

schedule_jobs [j0] [slot_max 100];;
[{time_b = 0; walltime = 5; nb_res = 5; set_of_rs = [{b = 1; e = 5}]}]

schedule_jobs [j1] [slot_max 100];;
[{time_b = 0; walltime = 5; nb_res = 100; set_of_rs = [{b = 1; e = 100}]}]

schedule_jobs [j0;j1] [slot_max 100];;

[{time_b = 0; walltime = 5; nb_res = 5; set_of_rs = [{b = 1; e = 5}]};
 {time_b = 5; walltime = 5; nb_res = 100; set_of_rs = [{b = 1; e = 100}]}]

schedule_jobs [j1;j0] [slot_max 100];;
[{time_b = 0; walltime = 5; nb_res = 100; set_of_rs = [{b = 1; e = 100}]};
 {time_b = 5; walltime = 5; nb_res = 5; set_of_rs = [{b = 1; e = 5}]}]

schedule_jobs [j0;j1;j2] [slot_max 100];;

[{time_b = 0; walltime = 5; nb_res = 5; set_of_rs = [{b = 1; e = 5}]};
 {time_b = 5; walltime = 5; nb_res = 100; set_of_rs = [{b = 1; e = 100}]};
 {time_b = 0; walltime = 5; nb_res = 5; set_of_rs = [{b = 6; e = 10}]}]
*)
(*
let js1 =  {time_b = 5; walltime = 5; nb_res = 10; set_of_rs = [{b = 1; e = 10}]}
let js2 =  {time_b = 10; walltime = 5; nb_res = 10; set_of_rs = [{b = 11; e = 20}]}
let js3 =  {time_b = 20; walltime = 5; nb_res = 10; set_of_rs = [{b = 21; e = 30}]}


let smax = slot_max 100

split_slots_prev_scheduled_jobs [smax] [js1]
[{time_s = 0; time_e = 4; nb_free_res = 100; set_of_res = [{b = 1; e = 100}]};
 {time_s = 5; time_e = 9; nb_free_res = 90; set_of_res = [{b = 11; e = 100}]};
 {time_s = 10; time_e = 1073741823; nb_free_res = 100; set_of_res = [{b = 1; e = 100}]}]

split_slots_prev_scheduled_jobs [smax] [js1;js2]
[{time_s = 0; time_e = 4; nb_free_res = 100; set_of_res = [{b = 1; e = 100}]};
 {time_s = 5; time_e = 9; nb_free_res = 90; set_of_res = [{b = 11; e = 100}]};
 {time_s = 10; time_e = 14; nb_free_res = 90; set_of_res = [{b = 1; e = 10}; {b = 21; e = 100}]};
 {time_s = 15; time_e = 1073741823; nb_free_res = 100; set_of_res = [{b = 1; e = 100}]}]





split_slots_prev_scheduled_jobs [smax] [js1;js2;js3]
[{time_s = 0; time_e = 4; nb_free_res = 100; set_of_res = [{b = 1; e = 100}]};
 {time_s = 5; time_e = 9; nb_free_res = 90; set_of_res = [{b = 11; e = 100}]};
 {time_s = 0; time_e = 4; nb_free_res = 100; set_of_res = [{b = 1; e = 100}]};
 {time_s = 5; time_e = 9; nb_free_res = 90; set_of_res = [{b = 11; e = 100}]};

 {time_s = 10; time_e = 14; nb_free_res = 90; set_of_res = [{b = 1; e = 10}; {b = 21; e = 100}]};
 {time_s = 15; time_e = 19; nb_free_res = 100; set_of_res = [{b = 1; e = 100}]};
 {time_s = 20; time_e = 24; nb_free_res = 90; set_of_res = [{b = 1; e = 20}; {b = 31; e = 100}]};
 {time_s = 25; time_e = 1073741823; nb_free_res = 100; set_of_res = [{b = 1; e = 100}]}]


split_slots_prev_scheduled_jobs [smax] [js2;js1] (* BUG *)


*)
