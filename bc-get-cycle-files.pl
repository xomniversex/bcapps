#!/bin/perl

# visit URLs for NOAA cycle files and download new ones

require "bclib.pl";

# I tend to use up CPU, so renice myself
system("renice 19 -p $$");

# by default, we are in development mode and keep our data files in my
# home directory (which probably needs to change)
# TODO: change default root dir below
# NOTE: this downloads cycle files into my git root, so github will
# eventually have a history of these; not sure if this is useful, but
# will do it until they complain

defaults("mode=devel&root=/home/barrycarter/BCGIT/data");

# different options depending on mode
# THOUGHT: should this be in bclib?
if ($globopts{mode} eq "prod") {
  # never cache or debug in production
  $NOCACHE=1;
  $DEBUG=0;
} elsif ($globopts{mode} eq "devel") {
  # debug in devel
  $DEBUG=1;
} else {
  die "MODE required";
}

# the URLs and what programs to run after downloading new files
# (currently, just downloads and does nothing)
%urls = (
"http://weather.noaa.gov/pub/SL.us008001/DF.an/DC.sflnd/DS.synop/" => "",
"http://weather.noaa.gov/pub/SL.us008001/DF.an/DC.sflnd/DS.metar/" => "",
"http://weather.noaa.gov/pub/SL.us008001/DF.an/DC.sfmar/DS.dbuoy/" => "",
"http://weather.noaa.gov/pub/SL.us008001/DF.an/DC.sfmar/DS.ships" => ""
);

# download the directories for all urls
for $i (sort keys %urls) {

  # what type of data are we getting (look at URL to figure out)
  $i=~m%\.([a-z]{5})/?$%||die("URL: bad format");
  $type=uc($1);

  # these directories must already exist
  dodie(qq%chdir("$globopts{root}/$type/")%);

  # download directory of files (cache if in development)
  cache_command("curl -R -m 300 -s -o files.txt $i","age=300");

  # look at files.txt to see which cycle files we need
  $list = read_file("files.txt");
  @cycles = ($list=~m%>(sn\.\d+\.txt.*$)%mg);

  # clean it up a bit
  map {s/<[^>]*?>//; s/\s+/ /g;} @cycles;

  # TODO: right now, just checking if file exists -- later, much check
  # timestamp/etc
  for $j (@cycles) {
    ($file, $date, $time, $size) = split(/\s+/,$j);

    # if file doesn't exist, push command on list to get it
    unless (-f $file) {
      # TODO: can I always rely on ENV{PWD}?
      push(@commands, "curl -R -m 300 -s -o $globopts{root}/$type/$file $i/$file");
    }
  }
}

debug(@commmands);

# run commands using gnu parallel
# TODO: maybe not best to use pipe here?

dodie('open(A,"|parallel")');
print A join("\n",@commands)."\n";
close(A);

# TODO: run repeatedly (vs cron)
