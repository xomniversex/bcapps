#!/bin/perl

# Simulates Sun/Earth/Moon system

require "bclib.pl";

# mass in kg

# xyz at the epoch (2011-01-01 0000 UTC) wrt solar system barycenter
# in km (xy is the ecliptic plane, x is direction to vernal equinox J2000.0)

# (dx/dy/dz in km/s)

# TODO: naming objects individually is inefficient

%sun = ("mass" => 1.9891*10^30,
	"x" => -6.243886115088563E+05,
	"y" => 1.062083997699179E+05,
	"z" => 2.400305101962630E+03,
	"dx" => 1.425074259611765E-03,
	"dy" => -1.068014319018527E-02,
	"dz" =>-1.402385389576667E-05
	);

%earth = ("mass" => 5.9736*10^24,
	  "x" => -2.629469163081263E+07,
	  "y" => 1.449571069968961E+08,
	  "z" => -1.207457863667849E+03,
	  "dx" => -2.982509096017993E+01,
	  "dy" => -5.315222157007564E+00,
	  "dz" => -7.367084768116921E-04
	  );

%moon = ("mass" => 734.9*10^20,
	 "x" => -2.648940524592340E+07,
	 "y" => 1.446321279486018E+08,
	 "z" => -2.055339080217336E+04,
	 "dx" => -2.895706787392246E+01,
	 "dy" => -5.878199883958461E+00,
	 "dz" => 7.710557110927302E-02
	 );

# gravitational constant in m^3kg^-1s^-2
$g = 6.6742867*10^-11;

debug("BEFORE",%earth);
$dist = twobod(\%earth, \%sun);
debug("AFTER",%earth);

$f = $g*$earth{mass}*$sun{mass}/$dist**2;

# force in m*kg*s^-2

# acceleration on earth in m*s^-2
$accel = $f/$earth{mass};

debug("F: $f, ACCEL: $accel");


# Given two bodies (hashref), update their positions and velocities
sub twobod {
  my($a, $b) = @_;
  # TODO: make sure I change the originals, not copies!
  my(%a) = %{$a};
  my(%b) = %{$b};

  debug("ARROW", $b->{x});

  debug("STUFF", $a, $b, \%a, \%b);

  # compute distance squared and vector b-a (from a to b), and update
  # positions based on current velocity
  my($dist2);
  my(%vec);
  for $i ("x".."z") {
    # the $i component of the vector pointing from a to b
    $vec{$i} = $b{$i} - $a{$i};
    # the contribution to d2 from this coordinate
    $dist2 += $vec{$i}**2;
    # update positions for both a and b based on current velocity
    $a{$i} += $a{"d$i"};
    $b{$i} += $b{"d$i"};
  }

  debug("A",%a);

  debug("VEC:",%vec,"DIST",$dist);

}
