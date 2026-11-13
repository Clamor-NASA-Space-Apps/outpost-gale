extends RefCounted
## How long a radio message takes from Mars to Earth on a given day: the Earth-Mars distance from JPL's
## "Keplerian Elements for Approximate Positions of the Major Planets" (Standish and Williams, Table 1, valid
## 1800 to 2050 AD; saved in the workspace at research/junior-astronaut/pages/jpl-ssd-approx-pos.html), divided by
## the speed of light. Computed, not live: the HUD labels it COMPUTED with the date it is for (workspace rule 4).
## Check: 12 Jan 2025 gives 0.642 au, the closest approach of that opposition (tests/ui_test.gd).

const AU_KM := 149597870.7  # IAU 2012 resolution B2
const C_KM_S := 299792.458  # the SI definition of the metre
# a, e, I, L, long.peri, long.node at J2000 and their rates per Julian century (au, rad, deg)
const EARTH := [1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0,
	0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0.0]  # Table 1 "EM Bary"
const MARS := [1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891,
	0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343]


## One-way light time in minutes for a moment given as Unix seconds (UTC).
static func minutes(unix: float) -> float:
	return au(unix) * AU_KM / C_KM_S / 60.0


static func au(unix: float) -> float:
	var t := (unix / 86400.0 + 2440587.5 - 2451545.0) / 36525.0  # centuries past J2000.0
	return _where(EARTH, t).distance_to(_where(MARS, t))


## The page's recipe: elements at T, Kepler's equation by Newton's method, then into the J2000 ecliptic.
static func _where(k: Array, t: float) -> Vector3:
	var el: Array[float] = []
	for i in 6:
		el.append(k[i] + k[i + 6] * t)
	var a := el[0]
	var e := el[1]
	var big_i := deg_to_rad(el[2])
	var node := deg_to_rad(el[5])
	var peri := deg_to_rad(el[4] - el[5])
	var m := deg_to_rad(fposmod(el[3] - el[4] + 180.0, 360.0) - 180.0)
	var ecc := m + e * sin(m)
	for _i in 8:
		ecc -= (ecc - e * sin(ecc) - m) / (1.0 - e * cos(ecc))
	var x := a * (cos(ecc) - e)
	var y := a * sqrt(1.0 - e * e) * sin(ecc)
	var cw := cos(peri)
	var sw := sin(peri)
	var co := cos(node)
	var so := sin(node)
	var ci := cos(big_i)
	return Vector3(
		(cw * co - sw * so * ci) * x + (-sw * co - cw * so * ci) * y,
		(cw * so + sw * co * ci) * x + (-sw * so + cw * co * ci) * y,
		sin(big_i) * (sw * x + cw * y))
