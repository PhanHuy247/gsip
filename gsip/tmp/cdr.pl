use File::Tail;
  $file=File::Tail->new("/opt/freeswitch/log/cdr-csv/Master.csv");
  while (defined($line=$file->read)) {
      print "$line";
  }
