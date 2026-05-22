

PCPS4PS5SwitchSwitch 2Xbox OneXbox SeriesMore Systems Log In Sign Up
GameFAQs

Search Game Titles
Boards
News
Q&A
Community
Contribute
Games
SimCity 2000 – Strategy Guide
PC 
Home
Guides
Q&A
Cheats
Saves
Reviews
Media
Board
GameFAQs  

Search this Guide for
   
BOOKMARK 
Would you recommend this Guide? Yes NoHide 
Strategy Guide (PC) by Sixfortyfive
Version: 1.2 | Updated: 02/18/2025
 Highest Rated Guide

+==============================================================================+
|                                                                              |
|                                 SIMCITY 2000                                 |
|                    A Strategy Guide for the Modern Player                    |
|                                                                              |
|                               by Sixfortyfive                                |
|                              v1.2 (2025-Feb-18)                              |
|                                                                              |
+==============================================================================+

================================================================================
    TABLE OF CONTENTS
================================================================================

I. About This Guide: Addressing Urban (Planning) Myths

II. RCI Zones: The Core of the Simulation

III. Property Taxes: The Margin of Error

IV. Recreation, Ports, and Neighboring Connections: Breaking the Population Caps

V. Land Value: The Key to Dense Zone Development
    1. The Water System: Actually Very Important
    2. Scenic Value: The Little Things in Life
    3. Pollution: Keep It at an Arm's Length
    4. Crime: A Minor Inconvenience

VI. Health and Education: Do They Even Matter?

VII. City Ordinances: Fine-Tuning the Simulation

VIII. The Map is 128x128 Tiles... Except When It Isn't.
      Also, Rotating the Map Literally Alters Your City.

IX. Power: An Important but Easy Choice

X. Transit: Keep It Simple, Stupid.

XI. How to Win on Hard Mode: A Crash-Course in Deficit Spending

XII. A Few Pointers for Disasters and Scenarios: A Goal-Oriented Approach

XIII. Going Above and Beyond: Attending to Other Citizen Demands
    1. Increasing Population and RCI Demand
    2. Reducing Traffic
    3. Increasing Land Value
    4. Reducing Pollution
    5. Reducing Crime
    6. Increasing Your Power Grid's Efficiency
    7. Increasing Your Water Grid's Efficiency
    8. Increasing Your Citizens' Life Expectancy
    9. Increasing Your Citizens' Education Quotient
    10. Reducing Unemployment
    11. Increasing Your Fire Department's Effectiveness
    12. Reducing Taxes and Balancing Your Budget
    13. Prioritizing City Development Via Newspaper Surveys

XIV. Acknowledgements

XV. Version History

================================================================================
    SECTION I: ABOUT THIS GUIDE
               Addressing Urban (Planning) Myths
================================================================================

This guide is written with the intent of breaking down important gameplay
details and strategies for SC2K players, both newcomers and veterans alike.
Specifically, its focus is to examine what actually does (and doesn't)
contribute to population growth. Many different facets of the simulation are
discussed, but mostly insofar as to how each of them directly contributes to the
growth of your city.

I decided to write this because--in returning to the game so many years after
its release--I've come across a shockingly large amount of misinformation online
regarding how the game actually works. There's a ton of "common knowledge" both
online and in print that is just full of outright lies. So, I've been conducting
a lot of tests of my own and keeping a lot of notes as I've played to examine
how a lot of different aspects of the game really work under the hood. After
playing for several months, I figure I'd tidy up those notes and make a guide
out of them for anyone else who also happens to be struck by the urge to indulge
in a little retro simulation game time.

This guide is not going to cover extremely basic things like "what do the
different windows do?" or "what is this tool/building for?" I'm assuming that
you already have a grip on the absolute basics and can at least start to
populate a city on your own. But if you've got a handle on at least that much,
and even if you're a long-time SimCity vet, then I think you might find some
useful information below.

One category that I deliberately *won't* go into very much detail on is
arcologies. This is because I find them to be pretty boring and against the
entire spirit of SimCity itself. The fun of the game is figuring out how to
design an effective city, be it for the sake of population, money, or quality of
life. The idea of a "pre-made city in a single building" sort of flies in the
face of the entire concept, and arcology-heavy cities just aren't something that
I'm interested in building or optimizing.

The vast majority of my testing has been done on the Windows 95 Special Edition
version of the game, with just a little bit of cross-checking on the DOS and Mac
versions to verify a couple of specific things. There's always a chance that
some details below may not apply to the specific version that you're playing on.
I've also tried to be very clear in my writing when I'm speaking with confidence
in how a particular thing works and when I'm not 100% sure and am still relying
on old community assumptions.

I encourage you to read further, as I think there's quite a lot of worthwhile
information to be found below, but I'll close this section with a tl;dr:

* The only things that are absolutely necessary for a functional city are power,
RCI zones, and satisfactory transit. You can get by for a very long time with
just these.

* By far the biggest factor that drives RCI zone development is how well you
adhere to the game's desired zone ratio, which changes as your population grows.
You can cut corners almost everywhere else and suffer little to no consequences
for it, at least when it comes to population growth.

* The property tax rates dictate how far you're allowed to stray from the
"correct" RCI ratio. A tax rate of 9% forces you to keep very close to the
proper ratio. Lower taxes give you more freedom to develop what you want. If you
go any higher than 9%, then it becomes nearly impossible to maintain a steady
population. On higher difficulties, you may have to lower taxes for industrial
zones specifically.

* RCI zones are the only things in the game that require functional transit, and
each zone type needs a valid path to each of the other two zone types. Don't
waste resources providing transit to other buildings unless you're just doing it
for aesthetic purposes.

* Recreational facilities, ports, and/or neighboring connections will become
necessary at some point in order to further increase your population. Don't
bother building them earlier than requested because they won't provide a benefit
until then (for the most part).

* Higher land value is the key to getting dense RCI zones to fully develop. Land
value is influenced by: a properly functioning water system, proximity to scenic
niceties (slopes, trees, water, parks), rubble, crime, and heavy-polluting
buildings. Some of these factors are more important than others.

* The health and education subsystems are largely irrelevant and
inconsequential. There are many things in the game that influence them, but they
do not have very much influence on the rest of the game.

* City ordinances influence RCI demand, revenue, and quality of life metrics in
very specific and measurable ways that are explained below.

* Rotating the map literally alters your city. Seriously.

================================================================================
    SECTION II: RCI ZONES
                The Core of the Simulation
================================================================================

Residential, commercial, and industrial zones are where your citizens live,
shop, and work, respectively, and they comprise your entire population and tax
base (until arcologies enter the picture). Everything else in SC2K comes second
and exists to service RCI zones. The only other things necessary for a city to
function are power and transit, and RCI zones are the only things in the game
that require or even utilize transit.

The game has an internal "golden ratio" of RCI zones that it wants you to build,
with some zone types being in greater demand than others. This ratio changes
over time as your population increases. The RCI demand meter is a decent guide
to follow if you don't know the true ratio, but be aware that it tends to
fluctuate a little due to random factors and sometimes lags behind the true
demand by a few months when you're in the process of rapidly expanding the city.

There are two general rules about the zone ratio to keep in mind over the course
of the game. First, R demand will always be approximately equal to C+I demand,
so R zones should make up about 50% of your city at all times, give or take a
little. Second, I demand will be much greater than C demand at the start of the
game (by more than 3-to-1 at very low populations), gradually even out at some
point after 100k population, and then C demand will overtake I demand for the
remainder of the game. At the start of the game, it's advisable to just keep
building R-C-I zones in a population ratio of about 4-1-3 until you reach a city
size of around 10k total citizens, then start using the demand meters as a guide
from that point onward since the meters won't be fluctuating as wildly every
time you plop down a new zone.

(For the record, the "correct" population ratio for very small cities appears to
be close to 48% R, 11% C, 41% I. Be mindful that it's based on *population*, not
land area. All other things being equal, I zones are likely to develop more
densely, and R zones are likely to develop less densely. So, when you're
plotting your zones, you're likely to need a little more R and a little less I
than the given percentages in order for the population to match the ratio. The
game's desired balance of C and I zones does not begin to shift until some point
after 10k total population.)

Adhering to the proper RCI ratio is the major factor for successfully developing
your city. You can cut corners almost everywhere else (crime, pollution,
education, etc.) and it won't deter new citizens from moving in so long as you
continue to properly balance the zones, ensure that they're powered, and ensure
that traffic congestion and commute times aren't abysmal. If a zone type isn't
developing at all despite being in high demand, then it probably means that it
does not have a valid transit path to the other two zone types.

================================================================================
    SECTION III: PROPERTY TAXES
                 The Margin of Error
================================================================================

The default tax rate is 7% for all three zone types. If you raise taxes to 9%
across the board, the game forces you to adhere to the proper RCI zone ratio
very strictly, but as long as you do so, demand for all 3 zone types will remain
very high. The lower you set your taxes, the more freedom you're given to stray
from the ratio and build zones as you please. Raising taxes any higher than 9%
will put you at the mercy of wild population swings outside of your control.
When playing on Easy mode, the default tax rate of 7% gives you a pretty good
balance of revenue-vs-leniency, and there usually isn't a major reason to adjust
this by more than 2% in either direction.

If you want to see how well you're adhering to the proper zone ratio without
being punished for straying too badly, then increase your taxes gradually after
you've built a small but stable city. Plop down some zones while you have taxes
set to 7% and let them fully develop. If the demand meters are out of balance
(some zones are in consistently higher demand than others), then build a little
more of the highest-demand zone and let them develop as well. Keep repeating
this until the demand for all 3 zone types stays consistently high. Then, bump
taxes up to 8% and observe the change in demand. If the RCI meters fall out of
balance, then continue building only the zones that have maximum demand, and
once again wait for them to finish developing. Once all 3 meters have maxed out
again, bump taxes up to 9% and repeat the process of building only those zones
that have maximum demand. If demand for all three zones stays high even when
taxes are at 9%, then it means that your RCI balance is pretty close to perfect.

Another way of checking how well you're adhering to the desired zone balance is
to open the Graphs window and check the unemployment rate. In cities with a
perfect RCI balance, unemployment will settle at 0%. The further you stray from
the desired ratio, the more the unemployment rate will gradually tick up. You
should take care to ensure that unemployment remains low--ideally at 5% or
below--and that it specifically never crests above 10%. That's the point at
which your city will start to succumb to severe population swings and zone
decay. Build and develop more of the high-demand zone(s) to bring down
unemployment and put things back into balance. (Unemployment also tends to
fluctuate a bit more when you're rapidly expanding the city. Don't worry too
much about this; it should only be a concern if unemployment remains high for
several months after your new zones have finished developing.)

Adjusting individual tax rates for the different zone types can be useful. If,
for example, you wish to reduce the impact of pollution from I zones, then you
can set I taxes to 9% while keeping R and C taxes at lower rates, allowing you
to build proportionally more R and C zones than normal. You can take this even
further by opening up the Industry window and separately adjusting the tax rates
for the individual industries. Four specific industries (Steel/Mining, Textiles,
Petrochemical, Automotive) pollute much more than the remaining 7 industries.
So, you can set the tax rate for the 4 worst polluters to 20% and then set the
remaining 7 industries to much lower values. As long as the average tax rate for
all 11 industries is 9% or less, your I zones won't be impeded from developing.
(Other documentation and strategy guides state that the low-pollution industries
require a highly educated city to attract workers. Testing suggests that this
isn't actually the case.)

Be aware that the difficulty level that you select at the start of the game can
put stricter constraints on industrial zone development and tax rates. When
playing on Easy mode, you can set I zone taxes to 9% just as you can with R and
C zones. On Normal mode, however, you typically can't take I zone taxes above 7%
without suffering zone decay. On Hard mode, you may have to lower I zone taxes
all the way to 4% in order for them to develop properly.

Tax revenue is calculated by this formula:

    TaxRevenue = TaxRate * Population / 75

(Other documentation and strategy guides suggest that land value is used in tax
calculations. This is untrue.) Each zone type calculates its revenue
independently. This formula also only applies to RCI zones. Arcology tax revenue
is calculated similarly, but arcology populations only provide 1/3 the amount of
revenue as those from RCI zones, and arcology populations are always split up
50% R, 25% C, and 25% I.

Tax revenue and RCI demand can be further influenced by enacting specific city
ordinances, which often sacrifice one for the sake of the other or for the sake
of a specific quality of life factor.

================================================================================
    SECTION IV: RECREATION, PORTS, AND NEIGHBORING CONNECTIONS
                Breaking the Population Caps
================================================================================

Once you hit certain population milestones, the status window will start showing
these messages:

    "Residents Demand Park / Zoo / Stadium / Marina"
    "Commerce Needs Connections / Commerce Demands Airport"
    "Industry Needs Connections / Industry Demands Seaport"

You must provide these facilities or services to the three zone types once
they're demanded. Their populations will eventually be capped and prevented from
growing otherwise. (As an aside, this is one reason why it's advisable to
satisfy each and every demand that shows up in the status window over the course
of the game. If you never address water shortages when they're announced or
decline to build fire stations when they're demanded, then you might also miss
out on recreational demands when they're occurring at the same time.)

The R zone population cap comes into play once both your city's residential
population hits 1000 and when its total population reaches 8000. Thereafter, you
need to build one of the following facilities from the Recreation list to raise
the R cap: big parks, zoos, stadiums, or marinas. (Small parks do NOT help!)
Each of these facilities will raise the R population cap by different amounts:

    Facility  Population Serviced   Cost  Pop/$     Size   Pop/Tile
    --------  -------------------  -----  -----  --------  --------
    Big Park       3000 residents   $150  20.0    9 tiles       333
    Zoo           16000 residents  $3000   5.33  16 tiles      1000
    Stadium       16000 residents  $5000   3.2   16 tiles      1000
    Marina         9000 residents  $1000   9.0    9 tiles      1000

Different facilities provide different strategic value. Big parks are actually
the most cost-effective choice, as they service many more residents per dollar
spent than the other options. They also raise nearby land values, which can be a
big help in making dense R and C zones grow. On the other hand, servicing a
large residential population with nothing but big parks will take up three times
as much land area as the other options, so you may want to consider the others
for that reason. Marinas provide a good balance of value and capacity,
especially for cities with ample waterfronts. (You can also artificially make a
1-tile lake to build upon.) Stadiums are actually less cost-effective than zoos.
Some other guides suggest that the more expensive recreational facilities
provide a bigger boost to your tourism industry than the cheaper ones, but if
this is true I've yet to observe it.

The R zone cap starts at 1000 residents. Building these facilities raises the
cap by the quantities listed above. So, if you grow your city to a total of 8000
citizens--4000 of them belonging to the R zones--the status window will start
flashing these recreational demands at you. If you then build a marina (+9000),
your R cap will be raised from 1000 to 10000, and you won't be bothered by more
recreational demands until your R population exceeds 10000. If you then add a
big park (+3000), a zoo (+16000), and a stadium (+16000) to your city, then your
citizens will be satisfied until you reach an R population of at least 45000.

The C cap comes into play once your city's commercial population hits 2000.
Thereafter, you need to build one of the following to raise the C cap:

    Structure         Population Serviced    Cost  Pop/$      Size   Pop/Tile
    ----------------  -------------------  ------  -----  ---------  --------
    Airport (Runway)     10000 commercial  ~$3750  ~2.67  ~15 tiles      ~667
    Road connection       2000 commercial   $1010   1.98    1 tile       2000

The values listed for the airport are approximate. The effectiveness of an
airport is determined entirely by its number of runways, which only take up a
1x5 plot of land each. After a runway is constructed, a certain number of
additional support buildings must then be constructed before another runway can
spawn. You can save some money by initially zoning your airport with a size of
just 1x5 to get that first runway to spawn, then worry about expanding it later
when more runways are demanded. (You may have to stretch that initial airport
plot to 2x6 or orient it in a different direction for the runway to actually
spawn; sometimes it's picky about the specific location.) Just make sure that
there's enough room for expansion as needed. It's advisable to expand the
airport zone in the shape of a square rather than a thin rectangle or any kind
of irregular layout, as building it in a square shape may make it easier for
specific support buildings to spawn in as needed. Running power lines through an
airport can also be tricky. I find it helpful to completely surround an airport
zone with power lines at first, then bulldoze excess power lines once the runway
spawns within the zone, as small 1x1 size support buildings do not develop on
tiles occupied by power lines.

As an alternative to an airport, you can just drag normal roads off the edge of
the map and opt to build a connection to a neighboring city for $1000 per
connection. This isn't as cost effective in the long run, but it does have the
advantages of taking up less land area while also helping RCI zones at the edge
of your city develop. You don't even have to link these off-map connections to
the rest of your city; you can just build isolated single-tile connections on
the whole other end of the map from where the rest of your city is, and they'll
work just as well. It also doesn't really matter whether you build all of your
connections to a single neighbor or distribute them evenly among the four; some
guides suggest that your neighbors will get a development boost of their own
when you make a connection to them, but if this has any tangible benefit for
your own city's development, then I've yet to observe it myself.

The I cap comes into play once your city's industrial population hits 10000.
Thereafter, you need to build one of the following to raise the I cap:

    Structure           Population Serviced    Cost  Pop/$      Size   Pop/Tile
    ------------------  -------------------  ------  -----  ---------  --------
    Seaport (Pier)         10000 industrial  ~$1800  ~5.56  ~12 tiles      ~833
    Rail connection        10000 industrial   $1525   6.56    1 tile      10000
    Highway connection     10000 industrial   $1600   6.25    4 tiles      2500

The values listed for the seaport are approximate. The effectiveness of a
seaport is determined entirely by its number of crane & pier combinations, which
spawn only on the shoreline and expand into DEEP water (150 ft deep or more,
must have clearance space 5 tiles out from land). After a pier is constructed, a
certain number of additional support buildings must then be constructed before
another pier can spawn. You can save some money by initially zoning your seaport
with just one or two tiles on the shoreline to get that first pier to spawn,
then worry about expanding it later when more piers are demanded. Just make sure
that there's enough room for expansion as needed. It's advisable to build the
seaport along a straight shoreline and zone it in blocks of 2x6 tiles for each
pier (as in: 2 tiles adjacent to the shore, 6 tiles back into land). When
another pier is required, expand the seaport to a size of 4x6 (4 tiles adjacent
to shore, still 6 tiles back into land). As you expand the seaport further, keep
doing so in additional blocks of 2x6. This will ensure that the proper number of
support buildings are created. As with airports, you might find it useful to
surround a seaport with power lines at first, then remove excess power lines
after it develops so that small 1x1 support buildings can spawn properly.

As an alternative to a seaport, you can opt to drag railways or highways off the
edge of the map to connect to a neighboring city for $1500 per connection, much
in the same way as road connections work for C zones. At a glance at the above
data, rail/highway connections may even look more appealing than a seaport due
to their lower cost and size, but in practice, I advise against building them
because of a bug (at least in the Windows and DOS versions). You may find that
if you build a rail/highway connection, save the game and quit, then reload your
city in a new play session, the game won't properly detect your rail connections
anymore. You can get around this bug by bulldozing an existing rail/highway
connection, which seems to force the game into re-checking your connections, but
then this means that you'll be forced to bulldoze/rebuild your connections every
time you start a new session. Best to just build a seaport instead and avoid the
hassle. (In my experience, this bug doesn't appear to happen as often with road
connections as it does with rail/highway connections, but I have observed it
happening to roads once after moving a city from the DOS version of the game to
Windows or vice-versa.)

Of course, a seaport requires specific terrain in order to function. Piers will
only spawn in water that's at least 150 ft deep. So, if you started building
your city on a map with a very low sea level, then you might not even be able to
create a functional seaport, and your I zones must rely on rail/highway
connections, bugs or not.

One important note: all of the "Population Serviced" values listed in all of the
above lists are based on the precise population milestones that you hit before
the status window starts filling up with more demands. In practice, it appears
that the true population values associated with each of these structures are
about 1.5x of their stated amounts. For example, the construction of a Zoo
raises the residential population cap from 1000 to 17000 (+16000), but in
practice, it seems that the player is allowed to grow their R zones to a
population of about 25000 (+24000) before the R zone demand begins to truly
crater. So, once you notice one of these demands, you don't have to worry about
satisfying them right away, as you do indeed have some wiggle room before they
become truly relevant.

And finally, there's no point in building any of these structures before they're
requested--for the most part. Building a bunch of stadiums or a huge
seaport/airport really early in the game won't induce any extra demand for any
of your RCI zones. In fact, building a larger than necessary seaport/airport can
be slightly detrimental because some of the buildings constructed within them
produce a moderate amount of pollution. The only structure within this category
that can be advantageous to build early--as far as I'm aware--is the big park,
due to the beneficial side effects that it brings to nearby land values. Off-map
road connections can also be used to provide valid destination zones for the RCI
zones at the edge of your map.

================================================================================
    SECTION V: LAND VALUE
               The Key to Dense Zone Development
================================================================================

Dense RCI zones can develop into a variety of sizes. 1x1 tile buildings have a
population of 10 citizens each, 2x2 (first-stage) buildings have a pop of 80
citizens each (20 per tile), 2x2 (second-stage) buildings have a pop of 120
citizens each (30 per tile), and 3x3 buildings have a pop of 360 citizens each
(40 per tile). The likelihood of an RCI zone attaining its maximum density is
dependent on its land value. Each zone type has different thresholds (I is the
most lenient; R and C are more strict), and several factors influence the land
value of any given tile, including: a properly functioning water system,
proximity to scenic niceties (slopes, trees, water, parks, clear terrain),
rubble, crime, and pollution. Some of these are more important than others.

------------------------------------------------
    1. The Water System: Actually Very Important
------------------------------------------------

The development of a fully functional water system is the single most important
factor in raising citywide land values, as any given city tile will have
drastically higher land value when it has access to water. It is best to design
a system of water pumps that can service your entire city even in seasonal
droughts while also not wasting too much land building more pumps than you
actually need. A single water pump's output can be measured with this formula:

    PumpOutput = SeaLevel * 5 + BorderingTiles * 10 + Precipitation / 2

This gives you the total number of city tiles that the pump can supply water to
over the course of the following month. (The game multiplies this value by 720
to report how many "gallons" of water that the pump produces. This is what's
displayed when you examine them with the query tool.)

* SeaLevel (can range from 0 to 31) is the most important factor, and it can
only be adjusted during the terrain editing phase; it's locked into place once
you start building. (This is why several scenario cities have very inefficient
water systems; many of them are built on maps with a bone dry sea level.) The
default value for this is 4 when you create a map with the default terrain
editor settings. To maximize this value, create a completely flat map in the
terrain editor that is at the highest possible elevation, and raise the sea
level to its maximum height as well. If you think flat maps are boring and want
to play on more varied terrain, then you can lower the sea level a bit; just be
aware that doing so will slightly nerf the output of your water pumps.

* BorderingTiles (can range from 0 to 8) is the number of fresh water tiles that
border the pump. To optimize this value, you can build a row of pumps, then a
row of fresh water tiles, and keep alternating between the two. As your city
grows, you can expand this water pump layout in a square as needed for maximum
efficiency. Arranging your water pumps like this is much more important in
cities that have a very low sea level than it is in cities that have a very high
sea level.

    P W P W P W P    P = water pump
    P W P W P W P    W = fresh water tile
    P W P W P W P
    P W P W P W P    As your city expands and requires more water,
    P W P W P W P    extend this layout by adding one row or column at a time.
    P W P W P W P    Keep it arranged in a square to maximize its efficiency.
    P W P W P W P

* The Precipitation value randomly changes from month to month and can be
retrieved from the newspaper weather reports. It usually ranges from 0 to 28,
and it can go higher than that during severe weather conditions (Blizzard,
Hurricane, Tornado). You should design your system of water pumps to account for
the worst-case scenario: months in which your city is experiencing an extended
drought and in which your pumps won't receive any bonus from the weather.

So, to summarize the water pump output formula with an example, let's say that
we've built a pump on a map that has a default sea level (4), is bordering 6
tiles of fresh water, and is undergoing weather with 15mm precipitation:

    PumpOutput = SeaLevel * 5 + BorderingTiles * 10 + Precipitation / 2
    PumpOutput = 4*5 + 6*10 + 15/2
    PumpOutput = 20 + 60 + 7.5
    PumpOutput = 87.5 (rounded down to 87)

This single water pump would then be collecting 87 tiles' worth of water this
month, and it would distribute that water out to 87 of your city's tiles during
the following month.

Water towers store excess water that your pumps produce, and they'll distribute
their reserves to the rest of your city during dry months in which your pumps
can't produce enough water on their own. Unfortunately, droughts in SC2K can
randomly last a very long time and completely deplete your towers' reserves
anyway, which means that it's usually more effective to just build more water
pumps in optimally designed patterns than it is to spend money and land area on
water towers.

(For the record, the query tool isn't accurate for water towers. The query tool
says that water towers store "40000 gallons" of water, but it's more accurate to
say that they store "400 tiles" of water, which would be equal to 288000 gallons
based on how the game calculates water pump output. Water towers always operate
in multiples of 100 tiles at a time. If your city's pumps produce an excess of
60 tiles of water in a month, then it'll round this up to 100 and fill up one of
your water towers by 1/4 of its max capacity. If your city experiences a 60-tile
drought in another month, then one of your water towers will lose 100 tiles of
its reserves to cover that gap. This can result in strange rounding errors in
very small cities where 50 tiles is a significant percentage of its total land
area. These rounding errors become less common as your city grows in size and as
you add more water pumps.)

Desalinization plants only work when they border salt water tiles. Their output
can be calculated with this formula:

    DesalinizationOutput = BorderingTiles * 20

In this case, BorderingTiles naturally refers to neighboring salt water tiles,
not fresh water. What complicates this formula a little bit in practice is that
it isn't run just one time for the whole plant; it's run 9 different times for
all 9 tiles of the plant, and the output is summed together. Don't think of
desalinization plants as a single building, but more like 9 individual buildings
that work together.

In the vast majority of situations, it's better to just stick with normal water
pumps than to bother with desalinization plants. A group of 9 water pumps will
almost always output more water than a desalinization plant in similarly
advantageous terrain. So, just keep building your water pump layout with
optimally-placed fresh water tiles. I would only ever consider building a
desalinization plant in cities with a low sea level and in which pre-existing
terrain is extremely advantageous for a desalinization plant, such as having a
small and perfectly-shaped peninsula where a single plant could be built already
surrounded by salt water on 3 of its sides or so. Those situations are going to
be few and far between.

A water system does introduce a high amount of pollution to your city at first,
but this can be neutralized by the construction of water treatment plants. A
single treatment plant can service up to 2000 city tiles; if your water grid is
bigger than that, then you'll need to build more treatment plants before they
become effective. Try not to build too many of them, though, as the plants
themselves do produce a little bit of pollution.

Finally, if you've scoured the internet for tips for this game, then you may
have come across something called the "phantom water pump trick." The idea
behind this trick is that you build a single water pump, connect it to power,
but DON'T connect any pipes to it. This appears to make the game believe that
you have a water surplus: the Graphs window reports a surplus and both the
status window and newspapers stop nagging you about shortages. In truth, this
trick only gets rid of those messages; it does not make your entire city
function as if it was watered. If you attempt this trick, then your unwatered
tiles will still exhibit the same low land values, stunted development, and
slightly higher crime rates as they would in any other un-watered city. The only
way to reap the benefits of a water system is to actually give your city water.
(That being said, this trick can still be useful if you just don't care about
any of that stuff. If you don't mind having lower population density or higher
crime, but you still want to get rid of the nag messages related to water
shortages, then that's the one and only time that the phantom water pump trick
is actually useful.)

----------------------------------------------
    2. Scenic Value: The Little Things in Life
----------------------------------------------

The land value of any given tile can be further raised or lowered by proximity
to specific scenery or buildings. Generally, when such scenery or buildings are
within a 4-tile distance of your RCI zones, the land value of your RCI zones
will start to be influenced. The exact distance can vary slightly from one
specific situation to another due to quirks in the game's calculations, but in
any case, this effect is most pronounced when such structures are placed
immediately adjacent to your RCI zones.

As far as I'm aware, these are the only tiles that will materially *raise* the
land value of other nearby tiles, listed in order from most to least potent: big
parks (massive boost), trees / small parks (these two are equal), slopes (the
more there are and the bigger they are, the better), water tiles (more expensive
to place than trees but still moderately useful), and clear terrain (Sims
apparently prefer to have some wide-open spaces). Combining them (planting trees
on sloped terrain, for example) makes them even more potent. A single-tree tile
is just as effective as a densely forested tile, so it's more cost effective to
spread a few trees over a large area than it is to plant them all in one spot.
Police stations technically don't raise land value on their own, but their
crime-suppressing effect will raise nearby land values a little bit in practice.
(Note that for the time being I've only tested all of this against R zones; I
can't yet say for sure that C or I zones behave favorably to the same things or
not. I've also only been testing against light density zones to ensure that
population, traffic, and pollution remain stable and consistent from one test to
the next.)

If you happen to be laying down dense R or C zones in a space of, say, 3x4
tiles, then instead of zoning the whole area, consider zoning a 3x3 space with
the remaining tiles filled by trees, perhaps also adding some trees to nearby
slopes if they happen to be close enough. If you're zoning a 6x6 city block of
dense C zones, then you *might* get lucky enough to have it develop into
multiple 3x3 maximum density buildings on its own, but in a lot of cases it's
likely to develop into some mix of lower density buildings. If you instead place
a big park in a corner of this block, then it's very feasible for the remaining
space to develop into three maximum density 3x3 buildings, which provides just
as much population as you could hope to achieve with the best possible
combination of 2x2 buildings (and big parks also help raise the R population
cap, as discussed earlier). If a 2x2 church happens to spawn in the corner of a
6x6 block of dense R zones, then consider de-zoning its neighboring 5 R tiles
and placing trees in their place, raising the land value of the remaining
buildings on that city block and increasing their likelihood of developing more
densely. There are several examples along these lines where the concept of
sacrificing some of the land area of your city for a raise in its land value can
actually pay off, at least if you're mostly concerned with raising your
population density.

Many other structures will lower the land value of nearby RCI zones--some of
them severely--and many more won't have any notable impact at all. Even things
that you might expect to be beneficial, like educational facilities (which are
commonly said to increase nearby land values) will not boost land value, and
they may actually chip away at the land value of adjacent zones if you have to
clear out attractive scenery to build them. The things that you really have to
worry about--in order with the worst offenders listed first--are: rubble,
Plymouth arco, Launch arco, Darco, Forest arco, coal plants, oil plants, gas
plants, prisons, and water treatment plants. Dense industrial zones are also
problematic (roughly as much as fossil fuel power plants), and specific
buildings that spawn within airport/seaport/military zones are also undesirable,
so they shouldn't be built next to R/C zones. (For completion's sake, I should
note that I have not yet tested radioactive waste that is left behind by the
meltdown disaster, and I expect it to be among the worst offenders on this list.
I also haven't gotten around to thoroughly testing abandoned buildings.)

In particular, the catastrophic effect that rubble has on nearby land values is
something that I expect a lot of players to overlook, so make sure to clean it
up! If you bulldoze and rezone a structure, then consider running power lines
all the way through the new zone, which clears out the rubble, prevents existing
buildings in the area from plummeting in value, and also allows the new zone to
develop more quickly. If you knock down a non-zoned building, then consider
planting trees over the remains. The De-Zone tool can be very useful in clearing
rubble for cheap. If you have a large plot of land filled with rubble, just make
sure that one tile within the area is zoned. Drag the De-Zone tool over the
whole plot of land, and it'll both de-zone the single zone tile AND clear out
all of the rubble for $1.

One more factor that supposedly influences the land value of your city is the
proximity to "downtown." According to some reputable guides, the game designates
the "center" of your city as downtown and makes land values slightly higher in
this area, basically to simulate the concept of a city's most attractive
locations coalescing in one place. I can't say for sure how pronounced this
effect is or how exactly it works--it's been a bit inconsistent for me from one
test to another--but I will say that I'm pretty sure that it's true, based on my
own observations. I've created very large, very symmetrical test cities where
higher land values tend to coalesce at the center of the map.

Most other structures in the game will not influence land value in one way or
the other, especially if they don't produce any crime or pollution. When benign
structures do influence land value, it's likely due to the changes you made to
the landscape to build them (such as building over clear terrain, which does
have inherent land value to neighboring zones that is lost in the process).

Road systems in general present a kind of contradiction in their effect on land
values and RCI zone development. Higher traffic engenders more local pollution,
which hurts land value and zone development, but the presence of road
intersections (where traffic often converges and worsens) increases the
likelihood that 3x3 buildings will develop. In fact, they're usually the *only*
places where I observe 3x3 buildings developing. I've created some subway-only
layouts that produce zero traffic, no transit-related pollution, and extremely
high land values, but they won't spawn 3x3 buildings in any RCI zones. So,
developing a road network that strikes the right balance of reasonable traffic
congestion, advantageously-placed street corner intersections, and a
not-too-high ratio of road tiles to RCI tiles is a worthwhile priority to have
if you're trying to get your population to develop to its maximum possible
density.

--------------------------------------------
    3. Pollution: Keep It at an Arm's Length
--------------------------------------------

Pollution does have an effect on land value in general, but probably not as
severely as you'd expect. *Citywide* pollution doesn't matter nearly as much as
*localized* pollution. In fact, localized pollution is the primary reason why
several of the buildings named above are on the worst-offender list for their
effect on local land values. The citywide pollution introduced by a dirty water
system or the absence of a Pollution Controls ordinance, for example, barely
makes a dent in the land value of individual RCI zones. (I've gone out of my way
to look for it, and I've only noticed a difference of about 1 point on any given
individual residential tile.) Similar things can be said about the taxation of
heavy-polluting industries (Steel/Mining, Textiles, Petrochemical, Automotive).
These actions *do* lower the citywide pollution values by quite a bit, but it
does not noticeably influence the land values of individual RCI tiles.

What does matter is the proximity of dense R/C zones to I zones and other
buildings that produce a lot of pollution. Building a fossil fuel power plant
adjacent to a residential neighborhood is a good way to completely stunt the
growth of that neighborhood. It's also a good idea to have a little bit of a
buffer between I zones and R/C zones. Such a buffer is often a good place to
construct location-agnostic buildings like parks. A distance of at least 4 tiles
between heavy-polluters and R/C zones is all that it really takes to keep this
under control (maybe 1 or 2 tiles more than that if you want to play it safe),
and you probably shouldn't make the gap too much larger than that or else you
might have to start worrying more about long commute times and traffic.

-----------------------------------
    4. Crime: A Minor Inconvenience
-----------------------------------

Crime really only has one consequence that I've noticed: slightly lower land
values. (I assume that it also makes riots more common when playing with
disasters enabled, but I've yet to really test this.) Lower land values, as
noted throughout this section, will stunt the development of your R/C zones.
Crime doesn't really have any impact on RCI demand otherwise; citizens will
willingly move into a dystopian gang-infested hellscape. Crime is primarily
reduced in three ways: via police stations (which suppress crime within a radius
of each station and is affected by funding levels), prisons (which reduce crime
citywide as long as your city already has a sufficient police presence), and the
Neighborhood Watch ordinance (which slightly lowers citywide crime rates).

The Neighborhood Watch ordinance is arguably most significant in cities with a
lot of light-density RCI zones. Light-density zones don't produce a whole lot of
crime in the first place, which makes the construction of a police station in
low-density areas not particularly cost-effective. You can enact this ordinance
to nearly eliminate crime in low-density areas, then focus the construction of
police stations in high-density areas where crime is more prevalent. Even if
your city is primarily high-density RCI zones, this ordinance is still
moderately useful in suppressing crime rates, and high-density zones benefit
more from the slightly higher land values that you get from reducing crime
anyway. It's pretty much always a good idea to pass this ordinance.

Police stations should be placed among dense RCI zones, where crime is most
prevalent and where its effects are most felt. You can use the Map window to
zero-in on crime-ridden areas. There are strategic justifications for
constructing police stations near I zones (where crime is *produced* in the
highest quantities) or near R/C zones (where the effects of crime are *felt* the
most severely). Placing police stations among I zones will be the most effective
at reducing the total amount of crime, while placing them among R/C zones will
help dense zones develop more effectively.

Prisons reduce citywide crime rates, but only if you already have a robust
police force; their effect is diminished otherwise. Prisons are useful in cities
of any size, and even though you can make a good case that they shouldn't be a
high priority in small cities due to their high up-front cost, you can also make
a case that building one early ensures that your police department will operate
at maximum efficiency right away. Prisons will also stop being effective if
their capacity ever exceeds 80%. If your first prison starts to get overcrowded,
then you could construct a second one, but it might be a better idea to start
building more police stations in crime-ridden areas instead.

Crime and land value have a minor feedback loop. High crime rates produce
slightly lower land values, and lower land values produce slightly more crime.

================================================================================
    SECTION VI: HEALTH AND EDUCATION
                Do They Even Matter?
================================================================================

Your citizens' life expectancy is raised by the presence of hospitals and the
passing of specific health-related ordinances. Their education quotient is
raised by the presence of schools, colleges, and the passing of specific
education-related ordinances. It takes a very long time before changes to either
metric begin to materialize, usually in the span of several decades. Your health
and educational service buildings each have a letter grade that can be viewed
with the query tool, and these letter grades correspond to the doctor-to-patient
ratio and teacher-to-student ratio. The more hospitals, schools, and colleges
that you build (and the more funding that you provide to them), the better these
ratios and grades will be. Higher grades for your facilities will typically
result in higher values for LE and EQ.

(Curiously, the rate of change for LE and EQ seems to accelerate when you have a
very stable population. When nobody is moving out of the city, these values
decay much more quickly in the absence of health and education-related services,
and they also rise much more quickly in the presence of robust health and
education-related services. If your population is *too* stable, and nobody ever
moves out of the city at all, then very strange things begin to happen and you
may eventually experience rollover glitches in LE or EQ.)

LE itself has some influence on EQ. When your citizens live longer lives, then
it means that a lower percentage of the population is of school age, which means
that your schools are less crowded, which improves the teacher-student ratio,
which improves the schools' grade, which can boost citywide EQ. If you construct
enough hospitals, schools, and colleges to ensure an A+ rating for each of them,
then sit back and let the simulation run for 100 years, you might find that you
can eventually bulldoze a few schools and still maintain an A+ rating for the
remainder, as you need fewer of them to maintain a high teacher-student ratio
than you did previously because a lower percentage of your population is
students.

It's commonly said that the high-tech and low-polluting industries require a
highly educated population to attract workers. There are supposedly four tiers
of EQ in this regard: 0-59, 60-100, 101-129, and 130-150. The ability for
high-tech industries to attract workers depends on which of those four tiers
your population happens to be. If it's in the below 60 range, then high-tech
industry will have a 20% reduction in growth compared to the base value in the
60-100 range. At 101 EQ, tech industries get a 10% boost, and at 130 EQ, they
get a 20% boost.

That being said, I've yet to observe a significant consequence for either low or
high LE or EQ in all of my years of playing SC2K. I've observed the ratios in
the Industry window over several playthroughs and tests and have yet to see a
change from one to another that didn't look like anything more than minor random
variance, regardless of how much I raised or lowered EQ. Even when I tilt the
tax rates to punish the "low-education" heavy polluters and favor the
"high-education" tech industries in a city whose population is dumb as bricks,
my overall industrial development does not suffer for it.

Pollution doesn't seem to have a noticeable impact on LE at all. The presence or
absence of water treatment plants doesn't influence LE, despite the fact that
treatment plants have a huge effect on citywide pollution. The same applies to
the Pollution Controls ordinance.

Libraries and museums have no observable effect on EQ. Documentation suggests
that they prevent your citizens' EQ from decaying with old age, but none of my
own testing has verified this.

Both of these systems seem to be rather undercooked in SC2K. To some extent, I
can see some logic in crime and fire protection not having a material effect on
RCI demand. You're intended to play the game with disasters turned on, and
having poor police/fire protection (theoretically) makes disasters more
prevalent. So, you can make a case that the player shouldn't be
"double-punished" by also making RCI demand suffer from poor police/fire
coverage. I suppose you could also make the case for citywide pollution to not
have a material effect on city development since a pollution-specific disaster
also exists (even though it's pretty inconsequential). But I've yet to really
observe any notable way in which LE or EQ impact the broader game. It seems like
they exist only as minor independent challenges, largely untethered from the
broader simulation.

I should note that I have read that low EQ makes riots more likely and that
high-tech industries just become easier to attract over the passage of time.
I've yet to really test either, though from spot-checking some of my cities I
suspect that the latter might be true, as I don't see the electronics industry
taking off in any of them in the early 1900s. In any case, it still begs the
question of how much time and money is worth investing in boosting LE or EQ.
Dealing with riots (or just disabling them) isn't especially difficult, and if
high-tech industries just passively become easier to attract over time anyway
then it kind of defeats the purpose of spending multiple decades to boost EQ.

You should build a hospital or school whenever the status window demands one, if
only to ensure that a more pressing demand can then later be seen when it comes
up. It's up to you as to whether you should build more than that. Or if you
should even fund your health or education departments.

================================================================================
    SECTION VII: CITY ORDINANCES
                 Fine-Tuning the Simulation
================================================================================

Here's a breakdown of what the individual ordinances actually do. "+1% R
financial" means that the ordinance's financial impact is equivalent to raising
R taxes by 1%. "+1% R demand" means that its impact on R demand is equivalent to
*lowering* taxes by 1%.

Values listed for the Financial and Demand columns are precise. Most values
listed in the Other column are approximate and can change a bit depending on the
specifics of your city. I've done my testing on cities that should be
representative of cities that are in continual states of development and
expansion. In extremely stable cities with consistently high RCI demand, for
example, you may see greater boosts to LE and EQ than what I've listed below.

    Ordinance             Financial     Demand    Other
    --------------------  -----------  ---------  -----------------------------
    1% Sales Tax          +1.000% C    -1.000% C
    1% Income Tax         +1.000% R    -1.000% R
    Legalized Gambling    +2.000% C               +25% to +50% crime
    Parking Fines         +0.500% R
    Volunteer Fire Dept   -0.333% R               increased fire protection
    Public Smoking Ban    -0.166% C               approx +2 LE
    Free Clinics          -0.500% R               circumstantial LE boost
    Junior Sports         -0.250% R               ???
    Pro-Reading Campaign  -0.166% R               approx +5 EQ
    Anti-Drug Campaign    -0.200% R               approx +2 LE
    CPR Training          -0.166% R               approx +2 LE
    Neighborhood Watch    -0.333% R               -15% to -30% crime
    Tourist Advertising   -1.000% C    +1.000% C
    Business Advertising  -1.000% I    +1.000% I
    City Beautification   -0.250% R    +1.000% R
    Annual Carnival       -0.333% C    +1.000% C
    Energy Conservation   -1.000% RCI             approx +8% power plant output
    Nuclear Free Zone                             prohibits new nuclear plants
    Homeless Shelter      -0.500% R    +1.000% C
    Pollution Controls    -1.000% I    -1.000% I  -25% to -50% pollution

And here's my evaluation of the ordinances, broken into different categories by
what I feel best exemplifies their use.

The ones that you should enact every time:

* Parking Fines: This one provides a little money for no observable impact on
RCI demand. Its description in other documentation suggests a slight decrease in
C demand (which I have not observed in any test) and a slight boost in mass
transit usage (which I have not yet tested).

* City Beautification: This has a positive impact on R zone development
equivalent to lowering R taxes by 1%, but its actual financial impact is less
than that. So, you can enact this ordinance, then raise R taxes by one point,
and you'll come out richer for no change to RCI demand.

* Annual Carnival: The same as City Beautification, except that it applies to C
zones instead of R.

The one that you should enact in very large (>100,000 population) cities:

* Homeless Shelter: This one's interesting. Its cost is dependent on your R
population, but it boosts the demand for your C zones. Basically, it becomes
cost-effective once your C population is more than 50% the amount of your R
population, and you can raise C taxes by 1% after enacting it to end up with the
same C demand as before.

The one that you should enact if you care about land value or crime:

* Neighborhood Watch: An inexpensive way to nearly eradicate crime in
light-density zones and also make a decent dent in crime in high-density zones.

The one that you should probably enact if you play with disasters on:

* Volunteer Fire Dept: More fire protection never hurts, especially if you have
a lot of rural, low-density areas where building more fire stations wouldn't be
very cost-effective.

The one that you should probably only enact in power-related emergencies:

* Energy Conservation: Adds about 8% to the output of all of your power plants.
This one is very expensive, and it's less justifiable if your power grid is
primarily serviced by cost-effective power sources (coal, hydro, microwave,
fusion) or if your RCI zones are primarily high-density. If either of those
factors are true, then it usually makes more sense to save up some money to
construct a new power plant and not dump money into this ordinance. The only
circumstance I can think of where I might enact this is when a disaster wipes
out one of my power plants and I don't yet have the funds to replace it.

The one that's a judgement call on crime-vs-income:

* Legalized Gambling: The financial boost you gain from this one depends on the
population of your C zones, but the increase in crime seems to be spread evenly
across all kinds of zones. That means that in small cities (which have a low C
population), you get proportionally less money for the crime that it generates,
but in large cities (which have a high C population), you probably don't need
the money as much since you've already been able to build a large city. The
increase in crime seems to be more pronounced in areas that fall outside of
police coverage, so if the increase in crime bothers you, then you can spend
some of the money that you earn from it to construct more police stations in
problem areas. It's pretty much a judgement call depending on your specific
needs and preferences. I prefer not to enact it, as it's not difficult to
generate money elsewhere, and I don't want more crime to bring down citywide
land values.

The ones you should enact if you care about life expectancy (LE):

* Public Smoking Ban, Anti-Drug Campaign, and CPR Training: Each of these
provides a small boost to LE, but only if you already have a decently performing
hospital network. From my own testing, I'd say that each of these ordinances can
boost your city's LE by about 2 over the course of several decades, but they
have a chance of taking it even higher than that if your city's population is
very stable and RCI demand remains consistently high. (Documentation suggests
that Anti-Drug Campaign influences crime or EQ; this does not seem to be true.)

* Free Clinics: This one provides a major boost to LE, but only if you DON'T
already have a decently performing hospital network. It seems to exist to cover
that gap.

The one you should enact if you care about education quotient (EQ):

* Pro-Reading Campaign: Adds about 5 points to citywide EQ. This can increase
even further if your city's population is very stable and RCI demand remains
consistently high.

The one you should enact if you care about citywide pollution:

* Pollution Controls: Cuts the total pollution output of the city by a decent
amount, but it's a drag on I demand and doesn't make an observable difference in
the land value for RCI zones or in your citizens' overall health. The amount of
pollution that is reduced is greater in cities that lack water treatment plants
or pollution-optimized industry tax incentives. If you do enact it, then it's a
good idea to also pair it with Business Advertising, since their effect on I
demand neatly cancels out.

The ones that are basically pointless, usually because they duplicate other
available actions:

* 1% Sales Tax: Functionally the same as raising C taxes by 1%. (It makes some
sense to pair this ordinance with Annual Carnival, as the effect on C demand
cancels out and you end up with more money overall.)

* 1% Income Tax: Functionally the same as raising R taxes by 1%. (It makes some
sense to pair this ordinance with City Beautification, as the effect on R demand
cancels out and you end up with more money overall.)

* Tourist Advertising: Functionally the same as lowering C taxes by 1%.

* Business Advertising: Functionally the same as lowering I taxes by 1%, though
it does make sense to enact it if you also choose to enact Pollution Controls,
as it neatly cancels out the drain on I demand that would occur otherwise.

* Nuclear Free Zone: It just doesn't do anything of observable consequence. It
prohibits the construction of new nuclear power plants and... that's it.
(Documentation suggests a slight boost to R and drain on I. I've yet to observe
this.)

The one that I can't figure out:

* Junior Sports: I've observed no change in any measurable quality of life
metric in any city in which this one is enacted or disabled. I also tried
testing it in cities with a ton of recreational facilities (big parks, etc.) for
the heck of it, and that didn't make a difference either.

================================================================================
    SECTION VIII: THE MAP IS 128x128 TILES... EXCEPT WHEN IT ISN'T.
                  Also, Rotating the Map Literally Alters Your City.
================================================================================

The total area of the city window is 128 by 128 tiles, with a measurement of one
acre per tile or about 5 by 5 miles for the whole city. On the Windows version,
if you hold the Alt key while inspecting a tile with the query tool, then the
game will also show the internal X and Y coordinates for that tile. Coordinate
(0,0) is the top corner of the map, (127,0) is the right corner, (0,127) is the
left corner, and (127,127) is the bottom corner. I prefer to call the top-right
edge of the map the "north" edge, as it represents the top of the Y-axis, and
it's consistent with how the Map window's overhead view works.

What's interesting is that if you click the rotate buttons on the toolbar, then
inspect the tile coordinates again, you'll see that the coordinates reset. The
new top corner is now at (0,0), and the old one has been rotated into a
different position. The "north" edge of the city hasn't been moved to a
different side of the screen; the new top-right edge has just become the new
north. This has a number of consequences that you might not notice unless you go
out of your way to look for them. Different behaviors can be observed at
different edges of the map, not every tile of a multi-tile building is
necessarily created equal, and some of the game's internal calculations are
performed upon blocks of tiles rather than individual tiles. These factors can
converge in strange ways.

You've probably noticed that SC2K prohibits you from constructing multi-tile
buildings, like power plants, at the very edge of the map. I believe that this
was put into place to limit the impact of a specific bug. You've also probably
noticed that dense RCI zones don't seem to properly develop at the very edge of
the map either. Plop a 3x3 dense I zone on the west edge of the map, and the
tiles at the very edge will probably remain at 1x1 in size no matter what you
do. But if you rotate the map clockwise so that the zone now rests at the north
edge of the map, you may actually see it develop into a 3x3 building. But then
if you rotate the map again, you might notice that the building appears
glitched, and if you try to bulldoze the glitched tile, the rubble that's left
behind rests in a slightly shifted position from where you actually built the
zone. The game doesn't seem to be able to keep the coordinates straight for
multi-tile buildings at the edge of the map, so it just doesn't (normally) let
you build them there.

The main city map is 128x128 in size, but some of the other "maps" that the game
uses are smaller than that. This is easy to observe by cycling through the
various views in the Map window and toggling the checkbox to display each of
them in the City window. The Traffic view, for example, always clusters its
readings in 2x2 blocks. Each of the 4 tiles within each block always share the
same color, which suggests that it's averaging the readings from the 4
individual tiles and displaying that in a 64x64 grid of 2x2 clusters rather than
displaying everything in a full 128x128 grid. You can observe similar behavior
in the Pollution, Land Value, and Crime Rate views. The Police Power, Fire
Power, Density, and Rate of Growth views are even more condensed, operating in
32x32 grids of 4x4 clusters.

Further inspection suggests that not all of these behaviors are limited to just
this display, but that the game actually spreads those values evenly among each
individual tile in a cluster. Land value is one such example. If you query each
of the 4 tiles in any individual land value cluster, you'll notice that all 4
tiles always have the exact same land value, even if the 4 tiles belong to
completely different structures. And if one large structure happens to be spread
across multiple different land value clusters, then different parts of the same
building will report different land values.

I have to imagine that this was done as a way to save on memory and CPU
requirements. SC2K cuts corners in other observable ways when you attain large
populations. You might notice, for example, that power and water readings are
updated immediately when you inspect tiles during the early phases of the game,
but once you pass about 50k population, the game starts limiting power/water
updates to once every in-game month instead. This was a game designed to run on
1993 computers of vastly different configurations, and sensible compromises were
made to keep it running smoothly on low-end machines.

But this "multi-tile cluster" method of calculation hits a snag once you notice
that not every tile of every building is treated the same. Some buildings don't
have this problem. If you "erase" half of a power plant with the magic eraser
trick, for example, then you just cut its power output in half, which suggests
that each individual tile of the plant is identical in function and that the
power generation is split evenly between them. However, many other multi-tile
buildings have what I call a "primary tile" that holds important information
about the entire structure. This is most easily observed in densely-zoned 3x3
RCI buildings. The left (or southwest) corner of each building appears to be its
primary tile, which contains all of the population measurements for the
building, and probably some other information too. (If you erase every tile of
the building except the primary one, you'll notice that the population stays
intact, but if you erase *only* the primary tile, then the entire population is
wiped out even if the rest of the building remains.)

When you rotate the map, the "southwest" position moves, which means that you
change the location of each of these primary tiles... which means that some of
them might now reside in a completely different 2x2 land value cluster. And
since land value is what dictates the development of dense RCI zones, this means
that some zones might have wildly different development spurts depending on how
you choose to orient the map.

Try it for yourself. If you happen to build a huge and dense city without ever
once rotating the map, then click that rotate button for the first time ever and
wait a few in-game months with the Graphs window open, then you might actually
observe a huge spike in population when the game does its next pass on land
value calculations for the new zone orientations.

This sort of behavior is also why I made a note several sections above saying
that 4 tiles is "usually" the distance at which neighboring buildings start to
influence each other when it comes to land value and pollution. This distance
can change somewhat depending exactly on how each building straddles a specific
2x2 land value cluster.

I've also noticed significantly different behavior in how dense zones develop
that changes depending on the specific coordinates I choose to build my roads.
For example, I've built this exact city layout a few different times, with the
only change being how far away I build it from the northwest corner of the map:

    +-----+-----+-----+
    | I I | C R | R R |
    | I I | C R | R R |     R  = 3x3 dense residential zone
    +-----+-----+-----+     C  = 3x3 dense commercial zone
    | I C | R R | R R |     I  = 3x3 dense industrial zone
    | I C | R R | R R |    -|+ = roads/intersections
    +-----+-----+-----+
    | I I | C R | R R |
    | I I | C R | R R |    Roads encompass 6x6 tile blocks.
    +-----+-----+-----+

When I build this layout with the top-left road intersection placed at (0,0),
only a small number of the R/C zones develop into 3x3 buildings. However, when I
build this layout with the top-left road intersection placed at (5,4), *several*
more of the R/C zones develop into 3x3 buildings, giving me a much greater
population for the exact same zone layout. I've consistently observed this
behavior across multiple tests. I wish I could zero-in on the exact causes for
it so that I could write a more precise guide on how to develop max-density
buildings, but this is all that I've been able to figure out so far. So, I
encourage you to try out some variations of your own and see what gets the best
results.

One more thing that I'm curious about but don't presently have the time to
investigate is how the Network Edition of the game changes any of this
location-based behavior. Since multiple people play on the same map at the same
time in that game and can thus be looking at the city from multiple different
angles, I'd have to imagine that the game either uses the host machine to
dictate the true and consistent coordinates for all of the connected players,
handles coordinates uniquely for each individual player, or perhaps has been
re-coded to some degree to account for or fix some of these inconsistencies.
Food for thought.

================================================================================
    SECTION IX: POWER
                An Important but Easy Choice
================================================================================

A power plant is literally the one required structure you need in order for a
city to develop and should therefore be the very first thing that you build, but
I'm putting this section all the way down here because strategically choosing
one is pretty straightforward, as I think most use cases have a very clear
answer and most options are irrelevant.

* Coal: This is what you go with if you just want something cost-effective at
the start of the game that also doesn't require specific terrain to function.
Other fossil fuel plants (oil, gas) may technically "pollute less," but they're
so inefficient that you'll either have to spend more money or build more of them
to match coal's output, which nullifies their advantages. And as long as you're
keeping the coal plant more than 4 tiles away from dense R/C zones, then you
don't actually have to worry about the pollution. Just stick it in a corner
somewhere or among your I zones and wash your hands of it.

* Hydro: This is what you go with if you want to avoid the hassle of the typical
50-year life cycle or if you want to eliminate power-related pollution. The
terrain requirement is the only major problem. If you want to power an entire
city via hydro plants, then create a proper map for it during the terrain
editing phase. You can combine hydro plants with water pumps to make an
efficient power + water network; alternate between one row of sloped waterfalls
(where you place the hydro plants) and flat land (where you place the water
pumps). The pumps will still get their boost from the waterfall tiles that the
hydro plants are built upon.

* Microwave and Fusion: These are what you go with once your city is very large
and you need a lot of power. Once your city reaches the size where it needs at
least 7 coal power plants to operate, stop building more coal plants and just go
with microwave. Once a single microwave plant is no longer enough to power the
whole city, then build a fusion plant and let the microwave plant expire. (If
your city gets so large that even a single fusion plant isn't enough anymore,
then either supplement it with more coal plants or replace it with two microwave
plants, whichever seems more fitting for your map.) Microwave power produces no
pollution, and fusion power produces such little pollution that it's
statistically insignificant.

None of the other options bring enough to the table to justify. Oil, gas, and
nuclear are less cost-effective than coal. Wind and solar are inconsistent and
less efficient than microwave. I've thought about doing a deep dive on how the
monthly weather changes influence wind and solar plants, but there's such little
incentive to bother. (There was a reason for me to do it for the water system
because I wanted conclusive answers pertaining to the efficiency of water
towers.) Yeah, I *guess* that you can argue that wind and solar are technically
cleaner than fusion and that they don't induce disasters like microwave or
nuclear and they don't have the same terrain limitations as hydro, but that's
just such an extremely specific convergence of priorities that leaves me with no
motivation to actually do the legwork for it.

I will, however, leave you with a table of the "true" output for each power
plant. "Megawatts" are what the game uses to display this information to the
player, and I'm like 99% sure that it's fake in the same way that "gallons" is a
fake measurement for how the game does water-based calculations. The true output
of a power plant seems to be measured in tiles, and this is what I have
observed:

    Plant      Output (in Tiles)    Cost  Cost/Tile  Lifespan
    ---------  -----------------  ------  ---------  ---------
    Fusion                  8864  $40000      $4.51  50 years
    Microwave               5664  $28000      $4.94  50 years
    Coal                     688   $4000      $5.81  50 years
    Nuclear                 1760  $15000      $8.52  50 years
    Oil                      752   $6600      $8.78  50 years
    Hydro                     39    $400     $10.26  unlimited
    Gas                      160   $2000     $12.50  50 years
    Wind                     ???    $100        ???  unlimited
    Solar                    ???   $1300        ???  50 years

Notice that all of the power plants that are 16 tiles in size (in other words:
all of them except hydro and wind) each have a total output that is a multiple
of 16 tiles. This isn't a coincidence. If you use the magic eraser to erase part
of a power plant, then you'll find that its output is reduced by proportionally
the same amount. For example, if you choose to erase 15 of the 16 tiles of a
fusion plant, then you'll reduce its power output to 554 tiles (1/16th of its
original output). Its pollution output will also be reduced similarly. You might
find this useful if you really want to min-max your land usage, as you can build
two fusion plants, then erase a few tiles of the second plant that you don't
actually need.

================================================================================
    SECTION X: TRANSIT
               Keep It Simple, Stupid.
================================================================================

When designing a transit system of any kind, it's best to keep in mind the
fundamental rules of transit in SimCity 2000:

* The only things in the game that actually need functional transit are
residential, commercial, and industrial zones. Literally everything else in the
game can function without transit and, in fact, doesn't even utilize transit at
all.

* Each of the three zone types requires transit to each of the other two zones
but not to itself. A residential zone tile, for example, needs valid paths to a
commercial zone and an industrial zone, but it does NOT require a path to other
residential zones. Inter-zone transit makes up the entirety of traffic in SC2K. 

* A Sim is willing to travel up to 3 tiles from his or her origin point to find
a valid method of transit: a road tile, a rail depot, or a sub station. So, when
designing road systems, make sure that every RCI tile in your city is no more
than 3 spaces away from a road. Sims can also travel up and down hills while
they're doing this, which is useful when you're attempting to place zones and
roads in scenic terrain.

* A Sim's DESTINATION, however, must be ADJACENT to transit. It can't be 3 tiles
away like the origin point can. This is something that can especially trip you
up when designing rail/subway systems if you're not careful. When designing such
a system, make sure that there are rail/sub stations placed adjacent to each of
the 3 zone types in many points throughout your transit system.

According to other reputable guides that go into more detail on the subject,
transit in SC2K is governed by a system in which each Sim's journey has a limit
of 100 "steps" to complete his or her trip, and each tile along the chosen
pathway subtracts a certain number of steps from that total based on the mode of
transportation and the traffic conditions. (To reiterate: a "step" is not the
same thing as a "tile"; crossing a single tile can subtract multiple steps from
a trip.) If the trip can be completed within the 100-step limit, then it's
considered to be a success, and the origin zone can be developed. If the trip
cannot be completed within the 100-step limit, then it's considered to be a
failure, and the origin zone will not develop; in the case in which it had
already been developed previously, it will likely decay soon due to no longer
having favorable traffic conditions.

Different modes of transit supposedly take specific numbers of steps during a
trip, and traffic congestion supposedly increases these values. Driving on a
normal road requires more steps than driving on a highway, so an intelligently
designed highway system in theory increases the distance that a Sim can travel
from one zone type to another. Highways also have greater traffic capacity than
normal roads, so trips that utilize highways are less prone to failing from
traffic congestion. Again: in theory. I'm couching a lot of this data in weasel
words like "supposedly" and "theoretically" and am not sharing the exact step
calculations here because it's been difficult for me to verify most of this
stuff through actual testing, and because the other guides that I'm referencing
often have accompanying comments noting that the step-calculation process is
prone to bugs that don't make alternative methods of transit as efficient as
they're "supposed" to be. From my own testing, all I can say is that I've yet to
observe cases in which a highway actually does increase the maximum allowable
distance of a trip when compared to normal roads, but they DO seem to have
greater traffic capacity than normal roads, so zones that are serviced by
highways at least anecdotally appear to be less prone to traffic-related decay
than zones that are serviced only by normal roads.

From my own testing, I've observed that the sims of a brand new city are
generally unwilling to drive more than about 24 tiles to reach their
destination. However, it seems that they're willing to drive at least halfway
across the map in very large cities, as I've played on several fully mature
cities that have all of their industrial zones pushed to the very edges of the
map. It would seem that there is something in the game that allows for sims to
make longer trips as your city grows, but I've yet to really nail down how it
works.

Rail and subway lines do indeed seem to allow for longer trips than roads
according to my own testing, but Sims seem to be rather reluctant to actually
use rail or subway stations if they don't absolutely have to do so. They'll
favor a subway station if that station happens to be within the 3-tile range of
their origin point, but if they're any further out than that, then they're
likely to get on a road and stay on the road if that road can take them to their
intended destination. Again, they'll switch from road to rail/subway or vice
versa in the middle of their trip if it's the only way to complete the journey,
but they're unlikely to switch if they don't have to.

I'd like to be able to give all the facets of trip generation and traffic a
proper breakdown in this guide, but it's been difficult to untangle its
complexities, and a lot of past experience of playing SC2K has always pushed me
back toward basic road designs anyway. Rail is a waste of land area, subway-only
layouts are challenging to optimize, highways take up a lot of space and aren't
needed when inter-zone trip lengths are kept to a minimum, and traffic
congestion ultimately isn't a major hurdle to city development if you know what
you're doing.

Keeping the different zone types in close proximity to each other--and thus
keeping travel distances short--is the key to creating successful transit
systems. This isn't a problem for residential and commercial zones, but the
heavy pollution and higher crime created by industrial zones make it undesirable
to have them placed right next to other zone types. Creating a 4-tile buffer
area next to I zones and filling that space with location-agnostic buildings
like police/fire stations, hospitals, schools, or parks is one way to
efficiently utilize that space. Alternatively, you could place the vast majority
of your I zones on one side of the map, the vast majority of your R/C zones
throughout the rest of your map, and just sprinkle in a few light-density tiles
of the missing zone types across each area to make sure that the main zones in
each area develop properly. You can have one edge of your map filled with 95% I
zones and 5% R/C zones, while the bulk of the rest of your map is 95% R/C zones
with 5% I zones sprinkled in. Furthermore, you can utilize off-road connections
to neighboring cities to provide more valid destinations for your own zones at
the edge of your map.

Constructing bus depots at busy intersections is a decent way to reduce existing
traffic if it really bothers you, for what that's worth. Open up the Map window,
switch to the traffic view, and place some bus depots at especially busy
intersections. You should notice a reduction in traffic in the immediate
vicinity.

One more thing that I want to make a note of from my own testing, though, is
that traffic congestion often *worsened* in cases where the population was
lowered. I'd have expected the opposite, and I think the reason for this might
be because abandoned buildings may not count as valid destinations (or at least
not *preferred* destinations) for how the game handles traffic. So, a Sim who is
trying to get from an R zone to a C zone and finds an abandoned building at the
target C zone has to now travel a little further in order to complete his trip.
That's just a theory, though.

I'll close this section of the guide with some examples of road layouts that you
may want to try out in your own cities:

    I I I | R R R R R R | I I I
    I I I | R R R R R R | I I I    R = residential zone
    I I I | R R R R R R | I I I    C = commercial zone
    C C C | R R R R R R | C C C    I = industrial zone
    C C C | R R R R R R | C C C    | = road
    C C C | R R R R R R | C C C
    I I I | R R R R R R | I I I
    I I I | R R R R R R | I I I
    I I I | R R R R R R | I I I
    I I I | R R R R R R | I I I
    I I I | R R R R R R | I I I
    I I I | R R R R R R | I I I

In this layout, you just create a bunch of parallel roads that are always 6
tiles apart. They never intersect. Even though it's impossible for a Sim to
travel from one corner of the city map to another, that doesn't matter because
Sims never actually *want* to do that anyway; they just need a path to the other
zone types. Every zone tile is within the 3-tile range of a road, and you've
dedicated the least amount of land area required to create a road system, which
saves you on transit maintenance costs. The main drawback of this layout (other
than it being aesthetically weird) is that maximum-density buildings are
unlikely to develop without the presence of street corners or intersections.

    C C C | C C C C C C | C C C
    C C C | C C C C C C | C C C     R  = residential zone
    C C C | C C C C C C | C C C     C  = commercial zone
    ------+-------------+------     I  = industrial zone
    R R R | R R R R R R | R R R    -|+ = road/intersection
    R R R | R R R R R R | R R R
    R R R | R R R R R R | R R R
    R R R | R R R R R R | R R R
    R R R | R R R R R R | R R R
    R R R | R R R R R R | R R R
    ------+-------------+------
    I I I | I I I I I I | I I I
    I I I | I I I I I I | I I I
    I I I | I I I I I I | I I I

This layout sticks to road grids that allow for 6x6 zone blocks. These are
straightforward and easy to plot, and they don't look particularly weird and
unrealistic like the prior example does. Regular intersections also increase the
likelihood of max-density 3x3 buildings developing, so long as you can
successfully keep land values in the area high.

    C C C | C C C C C C | C C C
    C C C | C C C C C C | C C C     R  = residential zone
    C C C | C C C C C C | C C C     C  = commercial zone
    t t --+-- t t t t --+-- t t     I  = industrial zone
    R R R | R R R R R R | R R R    -|+ = road/intersection
    R R R | R R R R R R | R R R     t  = trees
    R R R | R R R R R R | R R R
    R R R | R R R R R R | R R R
    R R R | R R R R R R | R R R
    R R R | R R R R R R | R R R
    t t --+-- t t t t --+-- t t
    I I I | I I I I I I | I I I
    I I I | I I I I I I | I I I
    I I I | I I I I I I | I I I

This is a modification of the prior layout that removes some "unnecessary" roads
and replaces them with trees. Remember, roads are only actually useful if they
serve the purpose of connecting one zone type to another. If you find any roads
that aren't being used at all, then you can repurpose that land for other uses.
In this example, trees have replaced some excess roads so that nearby land
values are raised, further increasing the likelihood that zones will develop
more densely.

    C C C | C C C C C C C C C | C C C
    C C C | C C C C C C C C C | C C C     R  = residential zone
    C C C | C C C C C C C C C | C C C     C  = commercial zone
    ------+-------------------+------     I  = industrial zone
    R R R | R R R R R R R R R | R R R    -|+ = road/intersection
    R R R | R R R R R R R R R | R R R
    R R R | R R R R R R R R R | R R R
    R R R | R R R       R R R | R R R
    R R R | R R R       R R R | R R R
    R R R | R R R       R R R | R R R
    R R R | R R R R R R R R R | R R R
    R R R | R R R R R R R R R | R R R
    R R R | R R R R R R R R R | R R R
    ------+-------------------+------
    I I I | I I I I I I I I I | I I I
    I I I | I I I I I I I I I | I I I
    I I I | I I I I I I I I I | I I I

This layout creates 9x9 sized city blocks, each leaving a 3x3 space in the
middle that can be filled with whatever you want that doesn't require transit:
police/fire stations, parks, whatever.

Each of the above are just a few examples of practical road layouts that can be
utilized or mixed-and-matched as desired. Feel free to experiment in wide-open
spaces and use whatever works best for you. One final pointer I'll give on roads
is that you should generally avoid making long diagonal roads in areas that
don't require them; they're typically less efficient than straight roads when it
comes to land usage, cost, and travel distances.

If you really want to maximize your above-ground land usage, then you can
consider making a subway-only layout. It's very expensive, and it can be awkward
to make sure that every tile has proper transit access (remember the 3-tile
rule), but it's possible. The following layout (as seen in a reader submission
from benjer's guide) marks subway stations with "S" and clearly illustrates the
coverage range of each station:

S x x x   x x x x x       x x x           x       S       x           x x x
x x x   x x x S x x x   x x x x x       x x x           x       S       x
x x       x x x x x   x x x S x x x   x x x x x       x x x           x       S
x           x x x       x x x x x   x x x S x x x   x x x x x       x x x
      S       x           x x x       x x x x x   x x x S x x x   x x x x x
x           x       S       x           x x x       x x x x x   x x x S x x x
x x       x x x           x       S       x           x x x       x x x x x   x
x x x   x x x x x       x x x           x       S       x           x x x
x x   x x x S x x x   x x x x x       x x x           x       S       x
x       x x x x x   x x x S x x x   x x x x x       x x x           x       S
          x x x       x x x x x   x x x S x x x   x x x x x       x x x
    S       x           x x x       x x x x x   x x x S x x x   x x x x x
          x       S       x           x x x       x x x x x   x x x S x x x   x
x       x x x           x       S       x           x x x       x x x x x   x x
x x   x x x x x       x x x           x       S       x           x x x       x
x   x x x S x x x   x x x x x       x x x           x       S       x

================================================================================
    SECTION XI: HOW TO WIN ON HARD MODE
                A Crash-Course in Deficit Spending
================================================================================

The difficulty selection at the start of the game affects four things: the
amount of money that you start with, the frequency of disasters (more on this
later), the thresholds for industrial zone taxes and development, and the
economic conditions of the broader SimNation (which influences overall RCI
demand and is supposedly cyclical).

On hard mode specifically, instead of starting with $20k or $10k in the bank for
you to freely spend as you wish, you start with a $10k bond that eats into your
budget via interest every single month until you pay off the bond in full. Bonds
will absolutely choke small cities to death if you don't start turning a profit
quickly, and it's the most likely reason why your city will spiral into failure
if you don't know what you're doing. With that in mind, these are the major
points to consider when starting out in hard mode:

* The $300 monthly interest is going to be the same no matter how much or how
little you build, so it's best to spend that initial $10k right away with the
intent of generating as much income as possible as quickly as possible. It
doesn't make sense to "save" any of the initial funds for a rainy day. You have
to spend money to make money. Even if you briefly go into the red for the first
couple of years, it'll be worth it in the end to generate more eventual revenue
more quickly, so long as you use all of those initial funds wisely. (The only
caveat here is that you may not want to risk putting yourself in the red if
you're playing with disasters enabled, as being locked out of the bulldozer tool
or being unable to rebuild infrastructure may be extremely costly.)

* The only thing that will generate revenue for you is the property tax
collected from RCI zones. So, focus on increasing your population first and
foremost.

* Do not allocate anything in your budget that would be an unnecessary recurring
expense. This means no police stations, fire stations, hospitals, schools,
colleges, or the vast majority of city ordinances. When designing your initial
city layout, you can save some empty plots for where you intend to *eventually*
build police or fire stations if you wish, but don't actually build them until
after the bond is paid in full. The city ordinances that are worthwhile to enact
at the start of the game are Parking Fines (free money), City Beautification
(cost-effective boost to R development), and Annual Carnival (cost-effective
boost to C development). The ideal strategy for tax rates may change from game
to game as the economic conditions aren't always exactly the same, but generally
speaking it's advisable to raise R and C zone taxes to 9% while lowering I zone
taxes to 4% at most.

* Since population is paramount, use nothing but dense RCI zones, not light.
Land value is important for getting dense zones to fully develop, so it's
worthwhile to boost it as long as it doesn't cost you too much money to do so.
Build your initial city area close to a fresh water source so that you can build
an efficient network of water pumps next to it. Don't build more water pumps
than you need (keep an eye on the water surplus % in the Graphs window or
periodically check the underground view). Consider plotting your zones close to
scenic areas like forests and slopes. Eventually, you should build some big
parks near your R or C zones; those serve a dual purpose of raising land values
and satisfying your R zones' recreational demands.

* A power plant is both required and expensive. The 50-year life cycle of a
power plant is something that you should keep at the front of your mind just as
much as the $10k bond, as not having the funds to replace a power plant when
needed will cripple your city. A worthwhile goal at the beginning of the game is
to build the largest city that can be powered by a single coal power plant. Coal
is a cost-effective option, and you should limit the initial size of your city
so that you don't have to worry about replacing more than one power plant at a
time. (As an alternative, you can edit the terrain ahead of time to facilitate a
large number of hydro plants instead. They are exempt from the 50-year life
cycle.)

* As you play, keep an eye on the federal interest rate in the Graphs window. If
it ever dips extremely low, like to 1%, then see if you can use it to issue a
new 2% bond and use that money to pay off your older 3% bond right away,
lessening the overall burden of monthly interest.

* As soon as you have $10k in the bank again, pay off that bond (except if your
power plant is about to expire; save funds for that first). After paying off the
bond, you can then more freely spend money on other services like police and
fire, or continue to expand your city as you wish.

* Playing with disasters enabled can be especially cruel on hard mode. Most
documentation suggests that disasters are likely to occur in greater frequency
on hard mode, but in my experience, it's more accurate to say that they tend to
occur in rapid succession on hard mode. I've lost count of the number of times
I've rebuilt a coal plant that was destroyed by a tornado, only for another
tornado to occur the very next month and take the new coal plant with it too.
And then a third one the month after that. If you suffer major damage from a
natural disaster like a tornado, then it *might* be worth waiting another month
or two for the tornado warning in the status window to subside before you spend
a lot of money to rebuild, as your rebuilding efforts might be wiped out right
away. And best of luck to you if you decide to build alongside a coast;
hurricanes are especially painful. Save frequently and reload as needed.

If you want an example of a starter city layout that can turn a profit, consider
the following example. This works best if you have a lot of flat land to work
with and more room to the right for expansion. Ideally, it should also be built
close to a fresh water source (lake/river, not ocean) so that you can build an
efficient cluster of water pumps near it:

      +-----+-----+-----+
    P | I I | R R | R R |                       P  = coal power plant
      | I I | C R | R R |                       R  = 3x3 dense residential zone
      +-----+-----+-----+                       C  = 3x3 dense commercial zone
      | I C | R R | R R |                       I  = 3x3 dense industrial zone
      | I C | R R | R R |                      -|+ = roads/intersections
      +-----+-----+-----+
      | I I | C R | R R |
      | I I | C R | R R |                      Roads encompass 6x6 tile blocks.
      +-----+-----+-----+

You should be able to construct this whole layout with the initial $10k that
you're given to work with. You should also have a little money leftover to build
a few water pumps, and it's worthwhile to do so for the sake of increasing land
value and population density, especially for the R and C zones.

(There are ways in which you may want to tweak this design to suit your own
tastes. It can be worthwhile to put more of a buffer between I zones and R/C
zones, so consider leaving some blank space between them for things you may want
to construct in the future, such as police/fire stations or big parks. It can
also be worthwhile to experiment with leaner road layouts that cost less to
maintain. It's just easier for 3x3 buildings to develop with the above layout,
and it's straightforward to build. The ratio of RCI zones in the above example
should be correct so long as the R and C zones eventually develop into a mix of
dense 2x2 and 3x3 buildings.)

After building this layout, sit back and wait until you've earned enough money
to expand it further. You might have to spend a few years in the red before the
zones fully develop and you have enough cash to continue building. If the
existing city layout is suffering from water shortages, then build more pumps
one at a time until you've satisfied their water needs. You can then extend this
layout by doubling it, with the second half being a mirror image of the first:

                      p
      +-----+-----+-----+-----+-----+-----+
    P | I I | R R | R R | R R | R C | I I |     P  = coal power plant
      | I I | C R | R R | R R | R C | I I |     R  = 3x3 dense residential zone
      +-----+-----+-----+-----+-----+-----+     C  = 3x3 dense commercial zone
      | I C | R R | R R | R R | R R | C I |     I  = 3x3 dense industrial zone
      | I C | R R | R R | R R | R R | C I |    -|+ = roads/intersections
      +-----+-----+-----+-----+-----+-----+     p  = big park
      | I I | C R | R R | R R | R C | I I |
      | I I | C R | R R | R R | R R | I I |    Roads encompass 6x6 tile blocks.
      +-----+-----+-----+-----+-----+-----+
                    p       p

Build the new zones and roads as the money comes in, keeping in mind that you
need to maintain the proper balance in your RCI ratio while doing so. (That is
to say: don't build all of the R zones first; make sure you're splitting up new
expansions between all 3 zone types.) This layout will push you close to the
limit of what can be powered by a single coal power plant. Continue to construct
water pumps one at a time as needed to ensure that there are no water shortages.
Building the big parks in the areas marked above will boost land values to help
the R zones fully develop (in addition to satisfying their recreational demands,
which start becoming relevant at around 8k total population). Keeping the R
zones clustered in the center of the city means that they should also get a
small boost in land value due to being in the centrally located "downtown" of
your city.

This layout should mature to a population between 15k to 20k and net you a
healthy yearly profit. Pay off the bond as soon as you can, then feel free to
further expand the city to your liking, or rework the existing area with more
niceties since you no longer have to be such a penny-pincher.

================================================================================
    SECTION XII: A FEW POINTERS FOR DISASTERS AND SCENARIOS
                 A Goal-Oriented Approach
================================================================================

I'd argue that disasters are a fundamental part of the game that players should
embrace once they've gotten their feet wet and are comfortable with the basics.
Police and fire stations are kind of pointless otherwise, as they have very
limited influence on the rest of the simulation. For those who like to play
adventurously, here are some tips to keep in mind:

* Emergency responders of any kind can often be helpful in preventing a disaster
from spreading even if they can't directly suppress it. Police can suppress
riots but not fires, and firemen can suppress fires but not riots. However,
either type of dispatch unit can block the path of those disasters from
spreading beyond the specific tile that they occupy.

* Act quickly and precisely to limit damage when possible. The bulldozer is the
best tool for preventing fires and riots from spreading. Neither type of
disaster can spread to clear terrain. Often, you won't have enough dispatch
units to completely surround them, but you can demolish all of the tiles that
border them to starve them if you have to. Your fire and police crews should be
prioritized to protect expensive structures that you really don't want to
bulldoze.

* Despite what a lot of other guides say, fires will NOT spread to rubble. You
don't actually have to clear it out while the disaster is ongoing. You also do
not have to place water tiles around a fire to keep it from spreading like some
other guides say; if anything, that will just make the clean-up process even
worse. Fires will burn up just about anything else, but they won't cross rubble,
clear terrain, or water.

* Riots, on the other hand, WILL spread to rubble. They're locked to roads at
first, but as they destroy more structures, they can then spread to the rubble.
They're actually more dangerous than fires if left unchecked.

* Minor floods can often be completely stopped by emergency first responders if
you act quickly enough. They can't actually beat the waters back, but if you
surround a flood tile on all sides with either police, fire, or military units,
then you can prevent the flood from spreading further and doing more damage.

* Damage from minor and major floods can be mitigated by not building expensive
infrastructure at the same elevation as the water. You can also build a 1-tile
slope around every major body of water to mitigate most of the potential flood
damage, if you wish.

* Hurricanes, however, will be brutal no matter what. You can avoid most (but
often not all) of the water damage by building away from the coast, but there's
nothing that will prevent the high winds from randomly knocking down buildings.
When playing on a coastal map, make sure to at least start your city far away
from the coast, and keep expensive infrastructure like power plants as far away
from danger as possible.

* When building an airport, make sure that it's in an area free of crash
obstacles. If your map has varying terrain, then the airport should be placed at
the highest elevation available. It should definitely NOT be placed near the
bottom of any sloped terrain, and you should not construct any tall buildings
(dense RCI zones, police stations, etc.) in its vicinity. Remember that airports
don't actually need to be connected to transportation; you can build them on the
far corner of the map, isolated from the rest of your city if you wish. Random
air crashes can still happen from time to time regardless of these precautions,
but this will cut down on most of them.

* Don't build a nuclear power plant if you're playing with disasters enabled.
The potential meltdown disaster leaves a semi-permanent radioactive nuisance
that you'll have to build around afterward. (Documentation says that fallout
lasts "a few hundred years." I've had it last for thousands of years in the
Windows version without it subsiding.)

* The microwave power plant disaster can leave behind some very expensive damage
(dispatch those fire trucks quickly!), but its effects aren't long-lasting like
a nuclear meltdown is.

* If your city reaches a population of 60,000 citizens but you DON'T permit the
military to build a base on your city (or if the military simply fails to find a
suitable plot of land for one), then there is a small chance that Maxis Man will
show up to fight off disasters for you. There's roughly a 1 in 4 chance that
he'll show up to help. Some other guides have suggested that these odds increase
if you have a high approval rating, but to my knowledge this hasn't been
verified.

* Make sure that you're thorough with clean-up. After the disaster subsides,
inspect the power and water grids in the Map window and ensure that there are no
severed connections. Take a good look at the roads and restore any that have
been destroyed. You don't *have* to clean-up the rubble, but it's a major drag
on land value, so consider tidying up any rubble that happens to be around dense
RCI zones. Either drag power-lines over it or plant trees on top of it.

Most scenarios involve cleaning up a specific disaster, then attaining a
specific population goal. (Only one officially released scenario, Las Vegas, has
a goal unrelated to population growth.) If you've read this whole guide, then
you should already have a pretty good idea of how to grow your population
effectively. So, I won't hold your hands with a step-by-step walkthrough for
each and every scenario, but I will provide an outline for the things that you
should prioritize for most of them:

* For starters, if you want to play one of the scenario cities without having to
deal with the disaster or timeline goals, then you can simply copy the scenario
file and change the copy into an ordinary city file. Just change the file
extension from SCN to SC2. This can be useful if you want to experiment without
the pressure of the deadline looming over your head, or if you just want to play
around with the Portland map without also having to worry about a huge volcano
demolishing the entire center of the city.

* The moment after starting a scenario, pause the game. Get a rough handle on
the potential damage of the disaster, if any.

* If you're playing a scenario with a meltdown disaster (Manhattan, Barcelona),
then it's actually possible to prevent the meltdown. If you can pause the game
before the actual meltdown occurs (in the Win95 version, try holding Ctrl+P when
loading the scenario and also when clicking through the introductory text), then
you can safely bulldoze the nuclear power plants to prevent them from exploding.

* Check "No Disasters" in the menu. It won't prevent the disaster that's
underway, but you really don't want to be bothered by another one during the
rebuilding phase.

* Let the disaster (if any) play out and mitigate the damage accordingly, if
possible.

* Keep the game paused whenever you're building. You have a time limit for each
scenario, so it's best to build while paused so that you don't waste time. After
building, un-pause to let the new areas develop, then pause again and reassess
how you should keep expanding the city.

* If the disaster wipes out a large swath of light-density RCI zones, then
consider re-zoning them to high-density before you let them rebuild.

* Check the power, water, and transportation infrastructure and repair any
severed connections. (Use the Map window to assist.) Take care to do this for
the entire city, not just the area that's affected by the disaster.

* Examine the map and query each power plant. If any of them happen to be
expiring before the end date of the scenario, then check the city's power usage
and see if you're going to need to set aside the funds to replace the power
plant when it blows.

* Many scenario cities have poor water systems--either not having enough pumps
for the whole city or not having all buildings connected to the grid. Since the
vast majority of scenarios have a population goal, and since dense zones develop
better when connected to water, take the time to expand the network of water
pumps so that the entire city is serviced. Make sure that any newly constructed
pumps border fresh water for maximum efficiency. Either build them next to
existing bodies of water, or create your own grid of pumps and water tiles as
needed.

* Open the Budget window and slash the funding for any expense that won't
actually help you grow the city. Cut funding for the fire, health, and education
departments to 0. Leave transit and police at 100. (You can technically skimp on
police if you really want to, particularly if the city has an overabundance of
police stations, but high crime is a deterrent for the growth of dense zones.)

* Open the Ordinances window and assess what should and should not be enacted.
Generally, you shouldn't enact any ordinances that don't directly contribute to
city growth. Volunteer Fire Dept is a waste of money if you disable disasters.
Energy Conservation is almost always a waste of money, period; if your power
grid is strained, then check to see if it's actually just cheaper to build
another coal plant than it is to keep this ordinance enacted for another 5-10
years. Pollution Controls hurt industrial growth, so make sure that industrial
taxes aren't set too high if you choose to enact it. Disable any ordinance that
only boosts LE or EQ; neither will make a positive difference for any scenario
goals. Use the ordinance chart from the previous section in this guide for a
more detailed analysis of what they do, if you need it.

* Do enact ordinances that explicitly increase the demand for RCI zones,
especially for any specific zone type that has a population requirement of its
own for the scenario that you're playing. Parking Fines (free money), City
Beautification (cost-effective boost to R development), and Annual Carnival
(cost-effective boost to C development) are especially useful ordinances that
should probably be enacted in any scenario. If the city's C population is more
than 50% of its R population, then enact Homeless Shelter. If your scenario
specifically has an industrial population goal, then enact Business Advertising.
If your scenario has a crime threshold goal (or if you want to reduce crime to
help dense zones develop), then disable Legalized Gambling and enable
Neighborhood Watch.

* Examine the city and look for any major inefficiencies that may need to be
addressed. If, for example, you see a large swath of abandoned buildings in a
residential section, but the R demand itself is high, then it might mean that
those R zones don't have sufficient transit to one or both of the other zone
types. If it looks like the distance from the R zone to the C/I zones is a bit
long, then consider sprinkling in just a couple of tiles of those other zone
types adjacent to the roads in that area to see if it helps the R zones develop.

* Use pre-existing but incomplete infrastructure to your advantage. If you see a
block of undeveloped RCI zones that lack transportation or power, then bring it
to them so that they can develop. If there are a lot of pre-existing roads that
are cutting through empty, wide-open spaces, then plot some dense zones
alongside them.

* When expanding the city, utilize large, wide-open spaces wherever you can. The
less landscaping you have to do to fit in new construction, the better.

* If you're short on open space for expansion, then examine whether it would be
more cost-effective to flatten some mountaintops or to bulldoze and re-zone
existing city blocks. If you notice, for example, that a police station, bus
depot, or big park is surrounded by light-density zones, then you may want to
consider bulldozing and re-zoning those areas as high-density so that they can
make better use of those facilities. If you notice areas with an excess of roads
(grids that result in very small city blocks where 3x3 buildings are impossible
to fit), then consider bulldozing some of the roads so that you can fit larger
blocks of dense RCI zones in that space.

* You don't have to address every single demand that the citizens make (and you
generally shouldn't; fire/health/education services don't get you anywhere when
it comes to scenario goals), but you might want to consider addressing any
specific demands that pop up in the status window. You should be especially
attentive for anything along the lines of "residents demand park" or
"industry/commerce needs connections," and you may not see those demands until
you address other concerns that are displayed within the status window. Refer to
the earlier section about population caps for more details. If residents require
recreational facilities, then build big parks next to dense R/C zones to help
them achieve maximum density. If commerce requires connections or an airport,
then consider making neighboring road connections at any edge of the map with
undeveloped zones so that those zones can reach potential destinations in
neighboring cities.

* You need to finish the scenario with more than $0 in the bank, and some
scenarios have a more strict financial goal than that. Don't shy away from
spending money to achieve your population goal; spend as much as you need to, as
quickly as you can, to expand the city to the required population. Worry about
attracting new citizens first and satisfying your financial goals second. (You
can make more tax revenue once you have more citizens to tax.) Focus more on
building the zone types that are in high demand, rather than lowering taxes on
the zones in low demand, and if any single zone type already has maximum demand,
then definitely don't limit your income by lowering that zone's tax rate any
further. Evaluate this on a case-by-case basis. There may be times when it's
more urgent to greatly lower taxes to increase population quickly (especially if
you only have a year or so left before the scenario deadline), or cases in which
you need to make money quickly.

* In my experience, at least in the versions that I've played, the game does not
seem to mind if you have to issue a bond or twelve to meet your financial goals.
Unrestrained deficit spending can cripple you if you intend to keep playing with
the city after the scenario has been solved, though, so don't go overboard with
it if that's the case.

================================================================================
    SECTION XIII: GOING ABOVE AND BEYOND
                  Attending to Other Citizen Demands
================================================================================

The bulk of this guide has been written with the goal of increasing your city's
population. If you've already got a good grasp on all of that, have been
singlemindedly min-maxing everything concerning growth, and now find yourself
bored and with more money in your city's treasury than you know what to do with,
then maybe now might be a good time to attend to the rest of the simulation and
concern yourself with other citizen demands.

In this section, you'll find a comprehensive list of tips for handling most of
the remaining facets of city development, including brief recaps of things that
have been discussed previously so that general strategies for all parts of the
game can be found in one place. Not all of the advice below will necessarily
help your RCI demand, but it might boost your approval rating quite a bit and
maybe even result in regular spontaneous parades held in your honor.

-------------------------------------------
    1. Increasing Population and RCI Demand
-------------------------------------------

* RCI zones can't be built on slopes or water. So, use maps with a lot of flat
land that can be developed.

* Build only dense zones and in patterns that facilitate large (3x3) buildings
when possible.

* Adhere to the proper zone population ratio. At the start of the game, this is
approximately 48% R, 11% C, 41% I. Build at this ratio until your city surpasses
10k total citizens, then use the RCI demand indicator on the toolbar as your
guideline for what to build from that point onward.

* Lower the property tax rate for a zone type to increase demand for that zone
(but don't lower taxes any further if demand for that specific zone is already
maxed out).

* Never raise the property tax rate for any zone type above 9% unless you also
enact specific city ordinances that compensate for the reduced zone demand.

* The difficulty level you select at the start of the game determines how high
you can set taxes for your industrial zones. On Easy mode, you can raise them to
9%, but on Normal mode, you typically can't take them over 7% without suffering
stunted development, and on Hard mode, you may have to keep them as low as 4% in
order for them to develop properly.

* Always enact the City Beautification and Annual Carnival ordinances. Enact
Homeless Shelter if your C population is more than 50% the amount of your R
population.

* Build efficient transportation systems so that as much of your land area can
be dedicated to RCI zones and not roads or other unpopulated structures.

* If certain zones in your city are not developing or are being abandoned
despite high demand for that zone type, then examine the transportation in the
area to confirm that each zone has a valid route to the other two zone types.

* Increase land values so that the RCI zones can attain their maximum density of
3x3 sized buildings. Also be aware that 3x3 sized buildings tend to only develop
at street corners or intersections.

* Attend to demands in the status window as they appear, especially anything
related to "residents demand recreation" or "commerce/industry demands
airport/seaport/connections."

* If you truly want to min-max population, then build Launch Arcologies once
they are invented and after you earn the right to build them (at 120k total city
population). Each of them eventually fills up to a max capacity of 65000
citizens (split 50% R, 25% C, 25% I). You can also use the magic eraser trick to
erase the arcology itself while still keeping its population intact. (This works
in the Win95 version. I have not tested other versions, nor have I tested if
there's a microsim limit that eventually caps the number of times that you can
do this.) This can inflate your city's population to huge sizes. Be mindful of
the problems that arcologies bring (increased local crime/pollution and lower
land values) and build around the area accordingly; keeping those metrics in
good shape will improve the the arcologies' "Condition" ratings.

-----------------------
    2. Reducing Traffic
-----------------------

* You can completely eliminate traffic by getting rid of all roads and opting to
build a subway-only transportation network instead. This comes with a lot of its
own challenges that make it impractical for most cities (awkward building
layouts, reduced zone density, exorbitant cost), but it is an option.

* Remember that RCI zones are the only things in the game that require transit,
and each zone type needs a valid path to each of the other two zone types.

* Be mindful of the fact that the traffic congestion of any given road tile is
not as important as the total length of the sims' commute. It's important to mix
all three zone types reasonably close together so that the distance between any
two pairs of zones is kept short. Sims will tolerate heavy traffic so long as
they don't have to stay in it for too long.

* Be aware that the Traffic graph has limited use. It reports the average
traffic congestion across all road tiles in your city, but this isn't a very
good way to measure your transit network's overall efficiency. To illustrate
this point: try building a 10x10 grid filled with nothing but road tiles in a
corner of the map far away from the rest of your city, then observe the changes
on the Traffic graph. You should notice a significant drop in reported traffic,
and this is because the new roads you just added dropped the average congestion
value... because literally nobody is using those useless roads. This might
reduce the number of traffic complaints in the local newspapers, but keep in
mind that it doesn't actually improve traffic congestion in the busy areas of
your city.

* The Map window is more useful when analyzing your city's traffic congestion,
as it allows you to zero-in on specific problem areas.

* Bus depots suppress traffic in their vicinity, with the effect being most
pronounced on roads that are closer to the depot. You can place them at
especially busy intersections for maximum effect.

* Sims are willing to change their mode of transportation in the middle of a
trip if they have to, but they prefer not to do so if it can be avoided. When
building a mixed road/subway network, make sure that there are some subway
stations adjacent to each of the three zone types (so that subway stations can
serve as valid destinations for all three zones) and that each subway station is
also placed adjacent to at least one road tile. This helps ensure that the
subway will actually be used.

----------------------------
    3. Increasing Land Value
----------------------------

* Make sure every tile of your city is connected to the water supply.

* Build your dense RCI zones next to big parks, trees, small parks, slopes,
water tiles, and/or clear terrain (listed in order of effectiveness). They'll
increase the land value of zones within a 4-tile range, the closer the better.

* Clean up any and all rubble. It is by FAR the biggest drag on land value.

* Do not build fossil fuel power plants (coal, oil, gas).

* Keep R and C zones at least 4 tiles away from I zones and other undesirable
neighbors (fossil fuel power plants, arcologies, prisons, water treatment
plants, ports, and military bases).

* The "center" of your city will receive a slight bonus to its land value. It's
a good idea to concentrate some dense R or C zones in this area so that they can
reap the benefits and develop more easily.

* Reduce pollution and crime.

-------------------------
    4. Reducing Pollution
-------------------------

* Enact the Pollution Controls ordinance. This hurts the demand for your I
zones, but that can be countered by also enacting the Business Advertising
ordinance.

* Open the Industry window and adjust the tax rate on a per-industry basis.
Raise the taxes on the 4 heaviest polluters (Steel/Mining, Textiles,
Petrochemical, Automotive) to at least 10%, the higher the better. Reduce the
taxes on the other industries so that the average tax rate across all industries
evens out to 9% or lower so that your overall I zone development doesn't suffer.
(I have read in other guides that the Food, Construction, and Aerospace
industries are also moderate polluters, but in my own testing, I have not
observed them to have a greater effect on pollution than the other low-polluting
industries.)

* Raise I zone taxes as high as you can (approx 9% on Easy, 7% on Normal, and 4%
on Hard), but reduce R and C taxes as low as you can afford to. This allows you
to increase your city's ratio of non-polluting R and C zones and decrease the
ratio of polluting I zones.

* Once you build a water system, make sure to also build water treatment plants
so that the pollution introduced by your water system is kept under control. You
need to build one treatment plant per every 2000 watered tiles in your city in
order for them to be effective. (This means that the absolute maximum number of
treatment plants that you could ever need is 9 plants for a full map. In
practice, you'll likely need a few less than that, as not every tile of the map
will utilize your water grid.)

* Use clean power sources (ideally hydro, microwave, or fusion).

* Place your heaviest polluting buildings as close to the very edge of the map
as you possibly can, with the very worst offenders placed at the corners. A
little bit of the pollution will spill over to your neighboring cities instead
of yours.

* When building an airport or seaport, don't make them larger than they need to
be. Their effectiveness is measured solely by their number of runways and piers,
respectively, and your citizens will let you know when they need more.

* If you're up for it, then build a subway-only transit network, as this
eliminates pollution from congested roads.

* Build bus depots at heavily congested intersections.

---------------------
    5. Reducing Crime
---------------------

* Enact the Neighborhood Watch ordinance.

* Build at least one police station per every 20000 citizens, which is the
minimum required to satisfy demands in the status window.

* Prioritize placing police stations either in places where crime is produced in
the highest amount (dense I zones) or in places where crime has the most
detrimental effect on growth (dense R and C zones).

* Use the Map window to zero-in on crime ridden areas. Build police stations in
those places.

* Increase the land value of your city where you can. Land value and crime have
a slight feedback loop.

* Build one prison and keep an eye on its capacity from year to year. If it ever
gets overcrowded (80% capacity or higher), then either build more police
stations or build another prison.

* The citywide crime rate must be held under 20 in the Graphs window in order to
receive the highest marks from the police chief. ("Crime is at an all-time
low.") Continue to build police stations until this threshold is met.

----------------------------------------------
    6. Increasing Your Power Grid's Efficiency
----------------------------------------------

* Decide which factors related to the power grid are most important to you:
total power output, cost per number of city tiles serviced, the 50-year cycle
for replacement costs, pollution, and/or reliability.

* For cost per tiles serviced, coal is effective at the start of the game, and
microwave and fusion are more effective once you've built a big enough city to
use up all of their power. Microwave and fusion are also the two most effective
for total power output, and they're both clean.

* Hydro is clean and exempt from the 50-year cycle. It requires specific terrain
to build, however. (You can get creative with landscaping by integrating hydro
dams into a water pump matrix, if you wish.)

* Oil and gas are generally less efficient fossil fuel sources than coal. Wind
and solar have low and inconsistent output. Nuclear carries the risk of a
meltdown and is not as cost effective as coal, microwave, or fusion.

----------------------------------------------
    7. Increasing Your Water Grid's Efficiency
----------------------------------------------

* When creating a map in the terrain editor, raise the sea level as high as
possible.

* When building water pumps, place them in a square matrix that alternates
between one row of pumps and one row of fresh water tiles.

* Dense RCI zones are the structures that need water the most, as they are more
likely to fully develop when watered. Ideally, you should make sure that every
tile of your city has access to water, but if for some reason you decide to pick
and choose which buildings are connected to your water supply, then at least
make sure that all dense RCI zones are serviced.

* Build one water treatment plant for every 2000 tiles in your city's water
grid. This eliminates the pollution that exists in your water supply.

* Do not build water towers or desalinization plants. In the vast majority of
cases, building more water pumps (in properly landscaped patterns) is more
effective.

------------------------------------------------
    8. Increasing Your Citizens' Life Expectancy
------------------------------------------------

* To satisfy demands in the status window, build at least one hospital per every
25000 citizens. To get the highest marks from the health department advisor
("Hospital services are trim, efficient, and responsive"), build at least one
hospital per every 16666 citizens.

* Continue to build more hospitals until they report an A+ rating via the query
tool. Keep in mind that these grades are updated only at the start of each new
year, so don't build too many all at once. Build one, wait a year, check the
grade, build another if the grade is still low, repeat.

* Enact the Public Smoking Ban, Anti-Drug Campaign, and CPR Training ordinances.

* The Free Clinics ordinance will not have a notable effect if you already have
a highly-graded hospital network.

* Keep RCI demand high and your population stable. LE (and EQ) changes at a
faster rate when nobody is moving out of your city.

---------------------------------------------------
    9. Increasing Your Citizens' Education Quotient
---------------------------------------------------

* Make sure that you're also attending to all of the tips in the life expectancy
section. If your citizens live longer, then they wait longer before having
children, which reduces the percentage of your population that happens to be
attending school, which improves the student-teacher ratio, which improves the
evaluation grades for your schools and colleges, which improves EQ.

* To satisfy demands in the status window, build at least one school per every
20000 citizens.

* Continue to build schools and colleges until you get the highest marks from
the education department advisor ("Educational services are adequate"). You will
need approximately 1 college for every 5 schools, maybe a little more or less.

* Continue to build more schools and colleges until they report an A+ rating via
the query tool. Keep in mind that these grades are updated only at the start of
each new year, so don't build too many all at once. Build one, wait a year,
check the grade, build another if the grade is still low, repeat.

* Enact the Pro-Reading Campaign ordinance.

* Once your city fully matures and both LE and EQ remain stable over multiple
decades, you may not require as many schools and colleges to maintain your EQ.
Check the grades on some of your hospitals, schools, and colleges to verify that
they still have an A+ rating. Try bulldozing one of them, waiting a year, and
verifying whether or not the letter grade drops on another instance of the same
facility. If the grade drops, then rebuild the facility, but if it stays at A+,
then it means that you no longer needed the old one and can continue without
rebuilding it.

* Libraries and museums don't actually seem to do anything, so there's no
pressing need to spend money to build them. If you wish to attain an A+ rating
for your libraries anyway, then build roughly one library per every 10000
citizens. Museums don't display a grade, but on the presumption that they cost
twice as much as libraries and can therefore service twice as many citizens,
then you can build one museum for every 20000 citizens if you wish.

-----------------------------
    10. Reducing Unemployment
-----------------------------

* Unemployment, as indicated in the Graphs window, functions as a measurement of
how well you're adhering to the game's desired RCI zone balance. As long as you
continue to increase the populations of your RCI zones in the proper ratio, then
unemployment will eventually drop to 0%.

* It is normal for unemployment to fluctuate a little bit during periods of
expansion, as some zones will populate faster than others and remain in flux for
a while before settling. Just focus most of your new development on the zone
types with the highest demand, and things should work themselves out over time.

* After your city's population crosses the 5-figure threshold, things should be
stable enough to consistently keep unemployment below 5%. If unemployment ever
teeters over 10%, then take immediate action to alleviate it. Consider lowering
taxes on low-demand zone types until development picks back up.

-------------------------------------------------------
    11. Increasing Your Fire Department's Effectiveness
-------------------------------------------------------

* To satisfy demands in the status window, build at least one fire station per
every 20000 citizens. You should arguably be doing at least this much even if
you're playing with disasters turned off, as it's useful to keep the status
window demands met.

* If you're playing with disasters turned off, then you can stop there. You can
also slash the funding of your fire department to 0% if you wish. If you are
playing with disasters enabled, then keep the department funded and consider
following through with the remaining tips.

* To get the highest marks from the fire department chief ("Fire coverage is
excellent"), build at least one fire station per every 10000 citizens.

* Spread fire stations evenly throughout your city. You don't want their
coverage zones to overlap too much, as that would entail paying more money to
cover the same area twice.

* Build fire stations in the parts of your city where fires would be most
disastrous. This could be near infrastructure that would be extremely costly to
rebuild (like power plants) or other pricey facilities (stadiums, prisons, etc).
Placing such buildings under strong fire protection reduces the risk of a
spontaneous fire occurring in their vicinity.

* Do not worry too much about fire coverage in unpopulated areas. Even if a fire
breaks out in a large forest, for example, it's very easy and cheap to just
bulldoze the surrounding trees to prevent the fire from spreading. Your fire
department's priority should be to protect the parts of your city that would be
costly to rebuild.

* Enact the Volunteer Fire Dept ordinance.

------------------------------------------------
    12. Reducing Taxes and Balancing Your Budget
------------------------------------------------

* First and foremost, make a decision on what you intend to actually spend your
tax revenue. Not every option in the budget window is worth funding for every
city or play style. Cutting out unnecessary expenses gives you more freedom to
lower taxes accordingly. The fire department is useless if you're playing
without disasters. The health and education departments are important if you
actually want to increase your city's LE or EQ, but neither of those are
important if you're only concerned with growth and revenue. Everything in the
Transit category needs to be 100% funded at all times... except the Subway,
which can be cut to 0% with no consequences.

* Give the earlier section on City Ordinances a thorough read to help you decide
which ordinances are worth enacting and which should be declined. For starters,
though, you should always enact Parking Fines, City Beautification, and Annual
Carnival. Their impact on RCI demand vs tax revenue is always cost-effective.

* Issuing bonds can be especially dangerous to small cities, as it can eat into
your revenue to the point where you can no longer remain solvent. Only issue a
bond in dire emergencies, such as when a power plant is destroyed and you don't
currently have the funds for a replacement, or when you're on a very tight time
limit in a scenario and need a quick cash infusion to develop the city very
quickly. Avoid issuing bonds otherwise and pursue a slow-but-steady growth
strategy. When you do have outstanding bonds, keep an eye on the federal
interest rate in the graphs window. If the rate dips sharply, then you can issue
a new bond at a lower rate and use that money to pay off your older bond with
the higher rate.

* You need to bring in enough tax revenue to remain solvent. This means enough
revenue to cover (1) all of the expenses in your budget, (2) an emergency fund
for replacing important infrastructure like power plants when needed, and (3)
whatever costs required to continue expanding your city as you choose. You
generally shouldn't lower your taxes unless all three of these conditions are
already satisfied.

* Your city's tax rate has an inversely proportional relationship to its RCI
demand. Strictly adhering to the game's desired zone ratios gives you the
freedom to raise taxes without significant consequences (up to about 9%), and
lowering taxes for any given zone type gives you more freedom to build more of
that zone type. When adjusting your tax rates, consider if you want to influence
individual zone demand, such as by keeping taxes high for polluting I zones and
keeping them low for non-polluting R and C zones.

* On harder difficulties, you have to keep I zone taxes lower. On Normal mode,
your I zone taxes shouldn't go higher than 7%, and on Hard mode, they may have
to stay as low as 4%.

* If the demand meter for any given zone type is already maxed out, then there's
little benefit to be had from lowering taxes any further for that zone type. It
might satisfy newspaper survey complaints about taxes or keep your city's
population a little more stable (which itself can accelerate LE and EQ growth),
but if you're going to lower taxes, then it's generally most helpful to do so
for the zone types that are currently in low demand.

-----------------------------------------------------------
    13. Prioritizing City Development Via Newspaper Surveys
-----------------------------------------------------------

* You can consult the newspapers to get a better idea of what problems your
citizens believe you should be addressing. Some newspapers are more helpful by
providing you a list of four issues that their readers have ranked in order of
importance; others will only name one outstanding issue. The total number of
newspapers to choose from increases as your city grows larger.

* If you're already satisfied with your city's condition for your own purposes,
and if there are no outstanding demands in the status window to address, then
try using the newspaper surveys to zero-in on the issues to work on. Solve
enough of them, and you might increase your approval rating enough to enjoy the
occasional spontaneous parade held in your honor.

================================================================================
    SECTION XIV: ACKNOWLEDGEMENTS
================================================================================

Most of the information presented in this guide stems directly from my own
testing and experience, but I would not have nearly the same amount of insight
into the inner workings of this game in the first place had I not owned the book
"SimCity 2000: Power, Politics, and Planning" by Nick Dargahi and Michael
Bremer. As far as I'm aware, this is still considered to be the definitive text
on the game to this day. While it's not *entirely* accurate and comprehensive (a
big motivation for the creation of this guide was to fill in the blanks that PPP
didn't), I still highly recommend it to anyone who wants to learn more detail
about SC2K's inner workings and development. It has some fantastic staff
interviews, too.

"Dan" from Benjer's guide for his subway-only transit layout.

araxestroy for some details regarding how certain code in the game actually
works.

================================================================================
    SECTION XV: VERSION HISTORY
================================================================================

v1.0 (2024-Dec-08)
    - Initial release.

v1.1 (2025-Feb-03)
    - Added a few more details regarding unemployment, city ordinances, power
      plant output, tax strategy, and scenario strategy.
    - Corrected some information regarding which industries pollute the most.
    - Added the "Going Above and Beyond" section.
    - Cleared up some formatting, spelling, and word choices.

v1.2 (2025-Feb-18)
    - Added minor details pertaining to land value.
    - Clarified specifics on how weather/precipitation influences water pumps.
    - Added information about how industrial zone growth is impeded on higher
      difficulty levels and requires lower tax rates.
View in: Text Mode

GameFAQsfacebook.com/GFAQstwitter.com/GameFAQsHelp / Contact UsChange Colors 
gamespot.commetacritic.comfandom.comfanatical.com

SitemapPartnershipsCareersTerms of UseDigital Services Act

Privacy PolicyDo Not Sell My Personal InformationReport Ad

© 2026 FANDOM, INC. ALL RIGHTS RESERVED.