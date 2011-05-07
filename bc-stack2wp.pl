#!/bin/perl

# Attempt to pull my stackexchange questions (not answers) into
# wordpress.barrycarter.info

# --fake: don't actually post anything

# NOTE: stack API results are gzip compressed

require "bclib.pl";

# work in my own directory
chdir(tmpdir());

# my WP password <h>(sorry, I can't hardcode it!)</h>
$pw = read_file("/home/barrycarter/bc-wp-pwd.txt"); chomp($pw);
# my name <h>(I'm OK with hardcoding this)</h>
$author = "barrycarter";
# my wordpress blog
$wp_blog = "wordpress.barrycarter.info";

# TODO: cheating and hardcoding this, but could get it from any of my stack ids
$assoc_id = "aa1073f7-7e3b-4d4d-ace5-f2fca853f998";

# find all stack sites (only need this because /associated below does
# NOT give URLs, grumble)

# below won't work when stack grows over 100 sites!
$fname = cache_command("curl 'http://stackauth.com/1.1/sites?page=1&pagesize=100'","age=86400&retfile=1");

system("gunzip -fc $fname > json0");
$sites = read_file("json0");

# parse..
$json = JSON::from_json($sites);
%jhash = %{$json};
@items = @{$jhash{items}};

# get data I need
for $i (@items) {
  %hash = %{$i};
  %hash2 = %{$hash{main_site}};
  $site{$hash2{name}} = $hash2{api_endpoint};
  $site_url{$hash2{api_endpoint}} = $hash2{site_url};
}

# find all my ids

$fname = cache_command("curl 'http://stackauth.com/1.1/users/$assoc_id/associated'","age=86400&retfile=1");

# unzip results
system("gunzip -c $fname > json1");
$json = JSON::from_json(read_file("json1"));
%jhash = %{$json};
@items = @{$jhash{items}};

# get data I need (my id on the site)
for $i (@items) {
  %hash = %{$i};

  # TODO: weird case, maybe fix later
  if ($hash{site_name} eq "Area 51") {next;}

  # map URL to id, not name to id
  $myid{$site{$hash{site_name}}} = $hash{user_id};
}

# and now, my questions on all sites
for $i (sort keys %myid) {
  debug($i,$site_url{$i});

  $url = "$i/1.0/users/$myid{$i}/questions";
  # filename for questions for this site
  $i=~m%http://(.*?)/?$%;
  $outname = $1;

  # my questions
  $fname = cache_command("curl '$url'","age=86400&retfile=1");
  system("gunzip -c $fname > $outname");
  $data = read_file($outname);

  debug("<data>$data</data>");

  # TODO: not sure why this happens
  unless ($data) {next;}

  $json = JSON::from_json($data);
  %jhash = %{$json};
  debug("JASH",unfold(\%jhash));
  @questions = @{$jhash{questions}};

  for $j (@questions) {
    %qhash = %{$j};
    debug("QHASH:", unfold($j));

    # question url
    $qurl = "$site_url{$i}$qhash{question_timeline_url}";

    $body = "I posted a question entitled '$qhash{title}' to $outname:<p>
<a href='$qurl'>\n$qurl\n</a><p>Please make all comments/etc on that site, not here.";

    post_to_wp($body, "site=$wp_blog&author=$author&password=$pw&subject=$qhash{title}&timestamp=$qhash{creation_date}&category=STACK&live=0");

    $qhash{qurl} = $qurl;
    debug("QHASH REF",unfold(\%qhash));
    push(@allquestions, \%qhash);
  }
}

# TODO: accepted_answer_id has vanished somehow

hashlist2sqlite(\@allquestions, "questions", "/tmp/stack1.db");

sub hashlist2sqlite {
  my($hashs, $tabname, $outfile) = @_;
  my(%iskey);
  my(@queries);

  for $i (@{$hashs}) {
    debug("I IS: $i",unfold($i));
    my(@keys,@vals) = ();
    my(%hash) = %{$i};
    for $j (sort keys %hash) {
      $iskey{$j} = 1;
      push(@keys, $j);
      $hash{$j}=~s/\'/''/isg;
      push(@vals, "\'$hash{$j}\'");
    }

    push(@queries, "INSERT INTO $tabname (".join(", ",@keys).") VALUES (".join(", ",@vals).")");
  }

  debug("QUERIES:", @queries);

  # create table and surround block in BEGIN/COMMIT
  unshift(@queries, "CREATE TABLE $tabname (".join(", ",sort keys %iskey).")");
  unshift(@queries, "BEGIN");
  push(@queries, "COMMIT;");

  my($tmpfile) = my_tmpfile();
  write_file(join(";\n",@queries), $tmpfile);
  system("sqlite3 $outfile < $tmpfile");
}

# TODO: turn off comments for these posts
# TODO: use WP *read* API to confirm no dupes
# post_to_wp($body, $options)
# site = site to post to
# author = post author
# password = password for posting
# subject = subject of post
# timestamp = UNIX timestamp of post
# category = category of post
# live = whether to make post live instantly (default=no)

sub post_to_wp {
  # this function has no pass-by-position parameters
  my($body, $options) = @_;
  my(%opts) = parse_form($options);
  defaults("live=0");

  # timestamp (in ISO8601 format)
  my($timestamp) = strftime("%Y%m%dT%H:%M:%S", gmtime($opts{timestamp}));

my($req) =<< "MARK";

<?xml version="1.0"?>
<methodCall> 
<methodName>metaWeblog.newPost</methodName> 
<params>

<param><value><string>thisstringappearstobenecessarybutpointlessinthiscase</string></value></param>

<param><value><string>$opts{author}</string></value></param> 

<param><value><string>$opts{password}</string></value></param>

<param> 
<struct> 

<member><name>categories</name> 
<value><array><data><value>Stack</value></data></array></value> 
</member> 

<member>
<name>description</name> 
<value><string><![CDATA[$body]]></string></value>
</member> 

<member> 
<name>title</name> 
<value>$opts{subject}</value> 
</member> 

<member> 
<name>dateCreated</name> 
<value>
<dateTime.iso8601>$timestamp</dateTime.iso8601> 
</value> 
</member> 

</struct> 
</param> 

<param><value><boolean>$live</boolean></value></param> 

</params></methodCall>
MARK
;

  write_file($req,"request");
  debug($req);

  if ($globopts{fake}) {return;}

  # curl sometimes sends 'Expect: 100-continue' which WP doesn't like.
  # The -H 'Expect:' below that cancels this
  system("curl -H 'Expect:' -o answer --data-binary \@request http://$opts{site}/xmlrpc.php");

  debug($req);

  debug(read_file("answer"));
}
