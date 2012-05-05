#!/bin/perl

# A simple starmap w/ HA-Rey style constellations (see
# db/constellations.db and db/radecmag.asc for data).

# Constellation boundary data: http://cdsarc.u-strasbg.fr/viz-bin/nph-Cat/html?VI%2F49

# Slew of options:
#
# --xwid=800 x width
# --ywid=600 y width
# --fill=0,0,0 fill color (as r,g,b)
# --time=now draw starmap at this time (GMT)
# --stars=1 draw stars
# --lines=1 draw constellation lines
# --lat=35.082463 latitude where to draw map
# --lon=-106.629635 longitude where to draw map
# --rot=90 rotate so north is at this many degrees (0 = right, 90 = up)

push(@INC,"/usr/local/lib");
require "bclib.pl";
require "bc-astro-lib.pl";
chdir(tmpdir());
$gitdir = "/home/barrycarter/BCGIT/";

# defaults
$now = time();
defaults("xwid=800&ywid=600&fill=0,0,0&time=$now&stars=1&lat=35.082463&lon=-106.629635&rot=90&lines=1");

# we use these a LOT, so putting them into global vars
($xwid, $ywid) = ($globopts{xwid}, $globopts{ywid});

# half width and height
$halfwid = $xwid/2;
$halfhei = $ywid/2;

# minimum dimension (so circle fits)
$mind = min($xwid, $ywid);

# the X graticule starts at $xwid/2-$mind/2, ends at $xwid/2+$mind/2
($xs, $xe) = ($xwid/2-$mind/2, $xwid/2+$mind/2);

# similarly for the y graticule
($ys, $ye) = ($ywid/2-$mind/2, $ywid/2+$mind/2);

debug("HW: $halfwid, $halfhei");

# write to fly file
open(A, ">map.fly");

# create a blank map (circle and graticule)
print A << "MARK";
new
size $xwid,$ywid
fill 0,0,$globopts{fill}
circle $halfwid,$halfhei,$mind,0,255,0
line $xs,$halfhei,$xe,$halfhei,128,0,0
line $halfwid,$ys,$halfwid,$ye,128,0,0
MARK
    ;

# draw stars/lines if requested (lines must preceed stars else they obscure)
if ($globopts{lines}) {draw_lines();}
if ($globopts{stars}) {draw_stars();}

system("cat map.fly");

close(A);
system("fly -i map.fly -o map.gif; xv map.gif& sleep 5");

# load stars into *global* array (used by other subroutines) just once
sub load_stars {
  unless (@stars) {
    @stars = split(/\n/,read_file("$gitdir/db/radecmag.asc"));
  }
}

# convert ra/dec to x/y for given arguments to this program, return
# -1,-1 if below horizon

sub radec2xy {
  my($ra, $dec) = @_;
  # first, convert to azimuth and elevation for this lat/lon/time
  my($az, $el) = radecazel2($ra, $dec, $globopts{lat}, $globopts{lon}, $globopts{t});
  if ($el<0) {return (-1,-1);}

  # polar coordinates: r = distance from center = 90-el ; el=0 -> edge
  my($r) = (90-$el)/90*$mind/2;
  # theta is reversed, because east is left of north when looking up
  # adding requested rotation as well; convert to radians
  my($theta) = -($az+$globopts{rot})*$DEGRAD;

  # convert to Cartesian
  my($x,$y) = ($halfwid + $r*cos($theta), $halfhei + $r*sin($theta));
  return ($x,$y);
}

# draw stars (program-specific subroutine)

sub draw_stars {
  load_stars();

  for $i (@stars) {
    # split into ra/dec/mag
    my($ra, $dec, $mag) = split(/\s+/, $i);
    # convert to x/y
    my($x,$y) = radec2xy($ra,$dec);
    # ignore below horizon
    if ($x<0) {next;}
    # circle width based on magnitude (one of several possible formulas)
    my($width) = floor(5.5-$mag);
    print A "fcircle $x,$y,$width,255,255,255\n";
  }

}

# draw constellation lines (program-specific subroutine)

sub draw_lines {
  load_stars();

  for $i (split(/\n/,read_file("$gitdir/db/constellations.dat"))) {
    # ignore non digit-digit lines
    unless ($i=~/^(\d+)\s+(\d+)$/) {next;}
    # from star $from to star $to
    my($from,$to) = ($1, $2);
    # find ra/dec of from and to stars
    my($ra1,$dec1) = split(/\s+/, $stars[$from-1]);
    my($ra2,$dec2) = split(/\s+/, $stars[$to-1]);

    # find x/y pos of stars above
    my($x1,$y1) = radec2xy($ra1,$dec1);
    my($x2,$y2) = radec2xy($ra2,$dec2);

    # if one part of line out of bounds, ignore
    if ($x1 < 0 || $x2 < 0) {next;}

    print A "line $x1,$y1,$x2,$y2,0,0,255\n";
  }
}

