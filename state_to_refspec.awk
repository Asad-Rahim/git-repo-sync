# Tests
## Restore

BEGIN { # Constants.
  local_refs_prefix = "refs/remotes/";
  remote_refs_prefix = "refs/heads/";
  
  tty_attached = "/dev/tty";
}
BEGIN { # Parameters.
  write_header("AWK started");
  trace_line("AWK debugging is ON");

  if(!must_exist_branch)
    write("Deletion is blocked. Parameter must_exist_branch is empty");
    
  if(!origin_1){
    write("Error. Parameter origin_1 is empty");
    exit 1002;
  }
  if(!origin_2){
    write("Error. Parameter origin_2 is empty");
    exit 1003;
  }
  if(!prefix_1){
    write("Error. Parameter prefix_1 is empty");
    exit 1004;
  }
  if(!prefix_2){
    write("Error. Parameter prefix_2 is empty");
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
    trace("next " $3 " " prefix_1 " " prefix_2);
    next;
  }
  
  refs[$3][dest]["sha"] = $1;
  refs[$3][dest]["ref"] = $2;
}
END { # Processing.
  dest = ""; ref_prefix = "";

  deletion_allowed = 0;
  unlock_deletion( \
    refs[must_exist_branch][remote_1]["sha"], \
    refs[must_exist_branch][remote_2]["sha"], \
    refs[must_exist_branch][local_1]["sha"], \
    refs[must_exist_branch][local_2]["sha"] \
  );
  trace_line("deletion allowance = " deletion_allowed " by " must_exist_branch);

  generate_missing_refs();
  declare_processing_globs();

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
  operations_to_refspecs();
}

function file_states() {
  switch (++file_num) {
    case 1:
      dest = remote_1;
      ref_prefix = remote_refs_prefix;
      break;
    case 2:
      dest = remote_2;
      ref_prefix = remote_refs_prefix;
      break;
    case 3:
      dest = local_1;
      ref_prefix = local_refs_prefix origin_1 "/";
      break;
    case 4:
      dest = local_2;
      ref_prefix = local_refs_prefix origin_2 "/";
      break;
  }
}
function prefix_name_key() { # Generates a common key for all 4 locations of every ref.
  $3 = $2
  split($3, split_refs, ref_prefix);
  $3 = split_refs[2];
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
function declare_processing_globs(){
  # Action array variables.
  split("", a_restore);
  split("", a_fetch1); split("", a_fetch2);
  split("", a_del1); split("", a_del2);
  split("", a_ff_to1); split("", a_ff_to2);
  split("", a_solv);
  # Operation array variables.
  split("", op_del_local);
  split("", op_fetch1); split("", op_fetch2);
  split("", op_push_restore1); split("", op_push_restore2);
  split("", op_push_del1); split("", op_push_del2);
  split("", op_push_ff_to1); split("", op_push_ff_to2);
  split("", op_push_nff_to1); split("", op_push_nff_to2);
  split("", op_fetch_post1); split("", op_fetch_post2);
  # Output Git refspec variables.
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
      trace("a_restore, no remote refs: " cr);
      a_restore[cr];
      return;
    }
    
    if(lr1 != rr){
      trace("a_fetch1, net fail: " cr);
      a_fetch1[cr];
    }
    if(lr2 != rr){
      trace("a_fetch2, net fail: " cr);
      a_fetch2[cr];
    }
    return;
  }

  if(lr1 == lr2){
    lr = lr1;
    
    if(!lr){
      trace("a_solv, no local: " cr);
      a_solv[cr];
      return;
    }
    
    if(!rr1 && rr2 == lr){
      trace("a_del2: " cr);
      a_del2[cr];
      return;
    }
    if(!rr2 && rr1 == lr){
      trace("a_del1: " cr);
      a_del1[cr];
      return;
    }
    
    if(rr1 == lr && rr2 != lr){
      trace("a_ff_to1: " cr);
      a_ff_to1[cr];
      return;
    }
    if(rr2 == lr && rr1 != lr){
      trace("a_ff_to2: " cr);
      a_ff_to2[cr];
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
  
  for(ref in a_ff_to1){
    op_fetch2[ref];
    op_push_ff_to1[ref];
    op_fetch_post1[ref];
  }
  for(ref in a_ff_to2){
    op_fetch1[ref];
    op_push_ff_to2[ref];
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
      if(refs[ref][remote_1]["sha"]){
        op_fetch1[ref];
        op_push_nff_to2[ref];
        op_fetch_post2[ref];
      } else if(refs[ref][remote_2]["sha"]){
        op_fetch2[ref];
        op_push_nff_to1[ref];
        op_fetch_post1[ref];
      }
    }
    if(is_side2){
      if(refs[ref][remote_2]["sha"]){
        op_fetch2[ref];
        op_push_nff_to1[ref];
        op_fetch_post1[ref];
      } else if(refs[ref][remote_1]["sha"]){
        op_fetch1[ref];
        op_push_nff_to2[ref];
        op_fetch_post2[ref];
      }
    }
  }
}
function operations_to_refspecs(){
  print "{[Results: del; fetch 1, 2; push 1, 2; post fetch 1, 2;]}"
  { # op_del_local
    for(ref in op_del_local){
      if(refs[ref][local_1]["sha"]){
        out_del = out_del "  " origin_1 "/" ref;
      }
      if(refs[ref][local_2]["sha"]){
        out_del = out_del "  " origin_2 "/" ref;
      }
    }
    print out_del;
  }
  { # op_fetch1, op_fetch2
    for(ref in op_fetch1){
      out_fetch1 = out_fetch1 "  +" refs[ref][remote_1]["ref"] ":" refs[ref][local_1]["ref"];
    }
    for(ref in op_fetch2){
      out_fetch2 = out_fetch2 "  +" refs[ref][remote_2]["ref"] ":" refs[ref][local_2]["ref"];
    }
    print out_fetch1;
    print out_fetch2;
  }
  
  { # op_push_restore1, op_push_restore2
    for(ref in op_push_restore1){
      out_push1 = out_push1 "  " refs[ref][local_1]["ref"] ":" refs[ref][remote_1]["ref"];
    }
    for(ref in op_push_restore2){
      out_push2 = out_push2 "  " refs[ref][local_2]["ref"] ":" refs[ref][remote_2]["ref"];
    }
  }
  { # op_push_del1, op_push_del2
    for(ref in op_push_del1){
      out_push1 = out_push1 "  :" refs[ref][remote_1]["ref"];
    }
    for(ref in op_push_del2){
      out_push2 = out_push2 "  :" refs[ref][remote_2]["ref"];
    }
  }
  { # op_push_ff_to1, op_push_ff_to2
    for(ref in op_push_ff_to1){
      out_push1 = out_push1 "  " refs[ref][local_2]["ref"] ":" refs[ref][remote_1]["ref"];
    }
    for(ref in op_push_ff_to2){
      out_push2 = out_push2 "  " refs[ref][local_1]["ref"] ":" refs[ref][remote_2]["ref"];
    }
  }
  { # op_push_nff_to1, op_push_nff_to2
    for(ref in op_push_nff_to1){
      out_push1 = out_push1 "  +" refs[ref][local_2]["ref"] ":" refs[ref][remote_1]["ref"];
    }
    for(ref in op_push_nff_to2){
      out_push2 = out_push2 "  +" refs[ref][local_1]["ref"] ":" refs[ref][remote_2]["ref"];
    }
  }
  print out_push1;
  print out_push2;

  { # op_fetch_post1, op_fetch_post2
    for(ref in op_fetch_post1){
      out_post_fetch1 = out_post_fetch1 "  +" refs[ref][remote_1]["ref"] ":" refs[ref][local_1]["ref"];
    }
    for(ref in op_fetch_post2){
      out_post_fetch2 = out_post_fetch2 "  +" refs[ref][remote_2]["ref"] ":" refs[ref][local_2]["ref"];
    }
    print out_post_fetch1;
    print out_post_fetch2;
  }

  print "{[End of results]}";
}


function write(msg){
  print msg >> tty_attached;
}
function write_header(msg){
  write("\n" msg "\n");
}
function trace(msg){
  if(!trace_on)
    return;

  if(!msg){
    print "Œ" >> tty_attached;
    return;
  }
  
  print "Œ " msg >> tty_attached;
}
function trace_header(msg){
  trace();
  trace(msg);
  trace();
}
function trace_after_line(msg){
  trace();
  trace(msg);
}
function trace_line(msg){
  trace(msg);
  trace();
}

END{ # Disposing.
  close(tty_attached);
}
