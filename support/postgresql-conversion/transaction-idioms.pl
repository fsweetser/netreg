  # begin a transaction
  my ($xres, $xref) = CMU::Netdb::xaction_begin($dbh);
  if ($xres == 1){
    $xref = shift @{$xref};
  }else{
    return ($xres, $xref);
  }

  # lock a list of tables
  my ($lockres, $lockref) = CMU::Netdb::lock_tables($dbh, \@locks);
  unless($lockres == 1){
    CMU::Netdb::xaction_rollback($dbh);
    return ($errcodes{"EDB"}, $lockref);
  }

  # rollback a transaction
  if ($res < 1){
    CMU::Netdb::xaction_rollback($dbh);
    return ($res, []);
  }


  # commit a transaction
  CMU::Netdb::xaction_commit($dbh, $xref);
