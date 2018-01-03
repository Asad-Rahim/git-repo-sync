# Tests
## Restore

BEGIN { # Constants.
  local_refs_prefix = "refs/remotes/";
  remote_refs_prefix = "refs/heads/";
  
  tty_attached = "/dev/tty";
}
BEGIN { # Parameters.
  tty_header("AWK started");
  tty_dbg_line("AWK debugging is ON");

  if(!must_exist_branch)
    tty("Deletion is blocked. Parameter must_exist_branch is empty");
    
  if(!origin_1){
    tty("Error. Parameter origin_1 is empty");
    exit 1002;
  }
  if(!origin_2){
    tty("Error. Parameter origin_2 is empty");
    exit 1003;
  }
  if(!prefix_1){
    tty("Error. Parameter prefix_1 is empty");
    exit 1004;
  }
  if(!prefix_2){
    tty("Error. Parameter prefix_2 is empty");
    exit 1005;
  }

  local_1 = "1 local ref " prefix_1;
  local_2 = "2 local ref " prefix_2;
  remote_1 = "1 remote ref " prefix_1;
  remote_2 = "2 remote ref " prefix_2;
}
BEGINFILE {
  file_states();
}
{ # Ref states preparation.
  if(!$2)
    next;
    
  prefix_name_key();
  if(index($3, prefix_1) != 1 && index($3, prefix_2) != 1){
    tty_dbg("next " $3 " " prefix_1 " " prefix_2);
    next;
  }
  
  refs[$3][dest]["sha"] = $1;
  refs[$3][dest]["ref"] = $2;
}
END { # Processing.
  dest = "";

  deletion_allowed = 0;
  unlock_deletion( \
    refs[must_exist_branch][remote_1]["sha"], \
    refs[must_exist_branch][remote_2]["sha"], \
    refs[must_exist_branch][local_1]["sha"], \
    refs[must_exist_branch][local_2]["sha"] \
  );
  tty_dbg("deletion allowance = " deletion_allowed " by " must_exist_branch);

  generate_missing_refs();
  declare_proc_globs();

  for(currentRef in refs){
    state_to_action( \
      currentRef, \
      refs[currentRef][remote_1]["sha"], \
      refs[currentRef][remote_2]["sha"], \
      refs[currentRef][local_1]["sha"], \
      refs[currentRef][local_2]["sha"] \
    );
  }
  actions_to_operations();
  operations_to_output();
}

function file_states() {
  switch (++file_num) {
    case 1:
      dest = remote_1;
      break;
    case 2:
      dest = remote_2;
      break;
    case 3:
      dest = local_1;
      break;
    case 4:
      dest = local_2;
      break;
  }
}
function prefix_name_key() {
  # Generates a common key for all 4 locations of every ref.
  $3 = $2
  split($3, split_refs, local_refs_prefix dest "/");
  if(split_refs[2]){
    # Removes "refs/remotes/current_origin/"
    $3 = split_refs[2];
  }else{
    # Removes "refs/heads/"
    sub("refs/[^/]*/", "", $3);
  }
}

function unlock_deletion(rr1, rr2, lr1, lr2){
  if(!rr1)
    return;
  if(!lr1)
    return;
  if(rr1 != rr2)
    return;
  if(lr1 != lr2)
    return;
  if(rr1 != lr2)
    return;
  
  deletion_allowed = 1;
}
function generate_missing_refs(){
  for(ref in refs){
    if(!refs[ref][remote_1]["ref"])
      refs[ref][remote_1]["ref"] = remote_refs_prefix ref
    if(!refs[ref][remote_2]["ref"])
      refs[ref][remote_2]["ref"] = remote_refs_prefix ref
    if(!refs[ref][local_1]["ref"])
      refs[ref][local_1]["ref"] = local_refs_prefix origin_1 "/" ref
    if(!refs[ref][local_2]["ref"])
      refs[ref][local_2]["ref"] = local_refs_prefix origin_2 "/" ref
  }
}
function declare_proc_globs(){
  # Action array variables.
  split("", a_restore);
  split("", a_fetch1); split("", a_fetch2);
  split("", a_del1); split("", a_del2);
  split("", a_ff1); split("", a_ff2);
  split("", a_solv);
  # Operation array variables.
  split("", op_fetch1); split("", op_fetch2);
  split("", op_del_local);
  split("", op_push_restore1); split("", op_push_restore2);
  split("", op_push_del1); split("", op_push_del2);
  split("", op_push_ff1); split("", op_push_ff2);
  split("", op_push_nff1); split("", op_push_nff2);
  split("", op_fetch_post1); split("", op_fetch_post2);
  # Output variables.
  out_del;
  out_fetch1; out_fetch2;
  out_push1; out_push2;
  out_post_fetch1; out_post_fetch2;
}
function state_to_action(cr, rr1, rr2, lr1, lr2,    lr, rr){
  if(rr1 == rr2 && lr1 == lr2 && lr1 == rr2){
    # Nothing to change.
    return;
  }
  
  if(rr1 == rr2){
    rr = rr1;
    
    if(!rr){
      tty_dbg("a_restore, no remote refs: " cr);
      a_restore[cr];
      return;
    }
    
    if(lr1 != rr){
      tty_dbg("a_fetch1, net fail: " cr);
      a_fetch1[cr];
    }
    if(lr2 != rr){
      tty_dbg("a_fetch2, net fail: " cr);
      a_fetch2[cr];
    }
    return;
  }

  if(lr1 == lr2){
    lr = lr1;
    
    if(!lr){
      tty_dbg("a_solv, no local: " cr);
      a_solv[cr];
      return;
    }
    
    if(!rr1 && rr2 == lr){
      tty_dbg("a_del2: " cr);
      a_del2[cr];
      return;
    }
    if(!rr2 && rr1 == lr){
      tty_dbg("a_del1: " cr);
      a_del1[cr];
      return;
    }
    
    if(rr1 == lr && rr2 != lr){
      tty_dbg("a_ff1: " cr);
      a_ff1[cr];
      return;
    }
    if(rr2 == lr && rr1 != lr){
      tty_dbg("a_ff2: " cr);
      a_ff2[cr];
      return;
    }
  }
  
  a_solv[cr];
}
function actions_to_operations(    ref, sha1, sha2, is_side1, is_side2){
  for(ref in a_restore){
    if(refs[ref][local_1]["sha"]){
      op_push_restore1[ref];
      op_fetch_post1[ref];
    }
    if(refs[ref][local_2]["sha"]){
      op_push_restore2[ref];
      op_fetch_post2[ref];
    }
  }

  for(ref in a_fetch1){
    op_fetch1[ref];
  }
  for(ref in a_fetch2){
    op_fetch2[ref];
  }

  if(deletion_allowed){
    for(ref in a_del1){
      op_del_local[ref];
      op_push_del1[ref];
    }
    for(ref in a_del2){
      op_del_local[ref];
      op_push_del2[ref];
    }
  }
  
  for(ref in a_ff1){
    op_fetch2[ref];
    op_push_ff1[ref];
    op_fetch_post1[ref];
  }
  for(ref in a_ff2){
    op_fetch1[ref];
    op_push_ff2[ref];
    op_fetch_post2[ref];
  }
  
  for(ref in a_solv){
    is_side1 = index(ref, prefix_1) == 1;
    is_side2 = index(ref, prefix_2) == 1;
    if(!is_side1 && !is_side2){
      continue;
    }
    if(is_side1 && is_side2){
      continue;
    }
    
    if(is_side1){
      if(refs[ref][local_1]["sha"]){
        op_fetch1[ref];
        op_push_nff2[ref];
        op_fetch_post2[ref];
      } else if(refs[ref][local_2]["sha"]){
        op_fetch2[ref];
        op_push_nff1[ref];
        op_fetch_post1[ref];
      }
    }
    if(is_side2){
      if(refs[ref][local_2]["sha"]){
        op_fetch2[ref];
        op_push_nff1[ref];
        op_fetch_post1[ref];
      } else if(refs[ref][local_1]["sha"]){
        op_fetch1[ref];
        op_push_nff2[ref];
        op_fetch_post2[ref];
      }
    }
  }
}
function operations_to_output(){
  print "{[Results: del; fetch 1, 2; push 1, 2; post fetch 1, 2;]}"

  for(ref in op_del_local){
    if(refs[ref][local_1]["sha"]){
      out_del = out_del "  '" origin_1 "/" ref "'";
    }
    if(refs[ref][local_2]["sha"]){
      out_del = out_del "  '" origin_2 "/" ref "'";
    }
  }
  print out_del;


  for(ref in op_fetch1){
    out_fetch1 = out_fetch1 "  +'" refs[ref][remote_1]["ref"] "':'" refs[ref][local_1]["ref"];
  }
  for(ref in op_fetch2){
    out_fetch2 = out_fetch2 "  +'" refs[ref][remote_2]["ref"] "':'" refs[ref][local_2]["ref"];
  }
  print out_fetch1;
  print out_fetch2;


  for(ref in op_push_ff1){
    out_push1 = out_push1 "  '" refs[ref][local_1]["ref"] "':'" refs[ref][remote_1]["ref"] "'";
  }
  for(ref in op_push_ff2){
    out_push2 = out_push2 "  '" refs[ref][local_2]["ref"] "':'" refs[ref][remote_2]["ref"] "'";
  }
  
  for(ref in op_push1){
    out_push1 = out_push1 "  +'" refs[ref][local_1]["ref"] "':'" refs[ref][remote_1]["ref"] "'";
  }
  for(ref in op_push2){
    out_push2 = out_push2 "  +'" refs[ref][local_2]["ref"] "':'" refs[ref][remote_2]["ref"] "'";
  }

  for(ref in op_solv_push1){
    out_push_solv1 = out_push_solv1 "  +'" refs[ref][local_1]["ref"] "':'" refs[ref][remote_1]["ref"] "'";
  }
  for(ref in op_solv_push2){
    out_push_solv2 = out_push_solv2 "  +'" refs[ref][local_2]["ref"] "':'" refs[ref][remote_2]["ref"] "'";
  }

  print out_push1;
  print out_push2;
  
  
  for(ref in op_fetch_post1){
    out_post_fetch1 = out_post_fetch1 "  +'" refs[ref][remote_1]["ref"] "':'" refs[ref][local_1]["ref"] "'";
  }
  for(ref in op_fetch_post2){
    out_post_fetch2 = out_post_fetch2 "  +'" refs[ref][remote_2]["ref"] "':'" refs[ref][local_2]["ref"] "'";
  }
  print out_post_fetch1;
  print out_post_fetch2;
  
  print "{[End results]}";
}


function tty(msg){
  print msg >> tty_attached;
}
function tty_header(msg){
  tty("\n" msg "\n");
}
function tty_dbg(msg){
  if(!debug_on)
    return;

  #print "Œ " msg >> tty_attached;
  print "Œ " msg " Ð" >> tty_attached;
}
function tty_line_dbg(msg){
  tty_dbg();
  tty_dbg(msg);
}
function tty_dbg_line(msg){
  tty_dbg(msg);
  tty_dbg();
}

END{ # Disposing.
  close(tty_attached);
}
