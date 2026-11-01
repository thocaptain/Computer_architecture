
set requested [list clk addr wdata mask wren async_data]
set selected [list]
foreach short $requested {
    for {set i 0} {$i < [gtkwave::getNumFacs]} {incr i} {
        set full [gtkwave::getFacName $i]
        if {[regexp {^TOP\.tbench\.([^\.\[]+)} $full -> name] && $name eq $short} {
            lappend selected $full
            break
        }
    }
}
if {[llength $selected] != [llength $requested]} {error "Missing GTKWave traces: $selected"}
gtkwave::addSignalsFromList $selected
gtkwave::/Edit/Set_Trace_Max_Hier 1
gtkwave::setLeftJustifySigs 1
gtkwave::highlightSignalsFromList $selected
gtkwave::/Edit/Data_Format/Hex
gtkwave::/Edit/UnHighlight_All
foreach full $selected {
    if {[string match {*mask*} $full]} {
        gtkwave::highlightSignalsFromList [list $full]
        gtkwave::/Edit/Data_Format/Binary
        gtkwave::/Edit/UnHighlight_All
    }
}
gtkwave::setFromEntry {24095 ns}
gtkwave::setToEntry {24110 ns}
gtkwave::setZoomRangeTimes 24095000 24110000
gtkwave::setMarker 24099500
gtkwave::setNamedMarker A 24099500 {Sample}
set f [open {/mnt/c/Users/ADMIN/Desktop/CTMT/Projects/Computer_architecture/99_doc/Report/gtk_sessions/WF11_3.ready} w]
puts $f "selected=$selected"
puts $f "start=[gtkwave::getWindowStartTime] end=[gtkwave::getWindowEndTime]"
puts $f [info commands gtkwave::*]
close $f
