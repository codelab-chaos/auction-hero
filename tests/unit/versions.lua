-- loads: versions.lua
-- Data versions: a kind moves only its own readings; a change by hand moves all.
local reads = { "market", "gear" }

local before = NS.VersionOf(reads)
local any = NS.DataVersion
NS.DataChanged("owned")
check("another kind leaves a reading alone", NS.VersionOf(reads), before)
check("but moves the version of any data", NS.DataVersion, any + 1)

NS.DataChanged("gear")
checkTrue("a kind read moves the reading", NS.VersionOf(reads) ~= before)

before = NS.VersionOf(reads)
local unseen = NS.VersionOf({ "recipes" })
NS.DataChanged()
checkTrue("a change by hand moves every reading", NS.VersionOf(reads) ~= before)
checkTrue("even of kinds never changed before", NS.VersionOf({ "recipes" }) ~= unseen)

check("without kinds, the reading is any data's version", NS.VersionOf(nil), NS.DataVersion)
check("readings are equal when nothing moved", NS.VersionOf(reads), NS.VersionOf(reads))
