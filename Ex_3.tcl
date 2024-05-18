#!/usr/bin/tclsh
# Define the procedure to calculate cell delay

proc calCellDelay {cellName inTran outCap riseFall libFile} {

#Displaying Cell Information__________________________________________________________________________________________________________________________________________________#

    puts "Cell Name: $cellName"
    puts "Input Transition: $inTran"
    puts "Output Capacitance: $outCap"
    puts "Library File: $libFile"
	
	set cell_name $cellName
	set input_file $libFile

	if {$riseFall} {
		set Rise_Fall "cell_rise"
	} else {
		set Rise_Fall "cell_fall"
	}
	puts $Rise_Fall


#Cell Parsing__________________________________________________________________________________________________________________________________________________#

# Read the input file
set input_handle [open $input_file r]
set data_lines  [read $input_handle]
close $input_handle

#Define the regular expression pattern for cell name 		Regexp -> "(cell\(a3_x2\)(.*\n*)*?)(cell\()"
set cell_pattern "\(cell\\($cell_name\\)\(\.*\\n*\)*\?\)\(cell\\(\)"

# Search for the pattern in the file content
if {[regexp $cell_pattern  $data_lines -> cell_info]} {
    puts "\n $cell_info:"
} else {
    puts "Cell $cell_name not found."
}


#timing table number parsing__________________________________________________________________________________________________________________________________________________
#Define the regular expression pattern to store table number 	Regexp -> "cell_rise\((([^)]+))\)"
set pattern_table_number "$Rise_Fall\\(\(\(\[^\)\]+\)\)\\)"

# Search for the pattern in the cell info
if {[regexp -all $pattern_table_number  $cell_info -> fall_rise_table]} {
    puts "Table number : $fall_rise_table"
} else {
    puts "Table $fall_rise_table not found."
}


#timing tables parsing__________________________________________________________________________________________________________________________________________________
#Define the regular expression pattern to store timing tables 	Regexp -> "cell_rise\(x4_1352_6x10\)\s*\{[^v]+values\(([^\)]+)\); \}"

set Rising_Falling_cell_pattern "$Rise_Fall\\($fall_rise_table\\)\\s*\\{\[^v\]+values\\(\(\[^\\)\]+\)\\); \\}"

set match1 [list]
set pattern_list [list]
set matches [regexp -all -inline $Rising_Falling_cell_pattern $cell_info]
set counter 0
foreach match $matches {
         if {[expr {$counter % 2}] == 1} { 
		 lappend pattern_list $match
    }
	set counter [expr {$counter+1}] 
}
set pattern_table [list]

#loop to modify table numbers and put them in 2D array
foreach table $pattern_list {
	set concatenatedData [string map {" " "" "\\" "" "\"" ""} $table]
	regsub -all {,} $concatenatedData { } concatenatedData
	set concatenatedData [split $concatenatedData "\n"]
	lappend pattern_table $concatenatedData
}


#LUT parsing__________________________________________________________________________________________________________________________________________________
#Define the regular expression pattern to parsing LUT elements     	Regexp -> "(lu_table_template\(x4_1352_6x10\)\s*\{([^\}]+)\})"

set pattern_table_info "\(lu_table_template\\(($fall_rise_table\)\\)\\s*\\{\(\[^\}\]+\)\\}\)"

	if {[regexp $pattern_table_info $data_lines -> table_info]} {
    puts "\n LUT: $table_info "
} else {
    puts "LUT $table_info not found."
}

#__________________________________________________________________________________________________________________________________________________________________________________________________________
#Define the regular expression pattern to take numbers of input transitions & output capacitance 	Regexp -> "index_1\( "(.*?)" \) ;"

if {[regexp {index_1\( "(.*?)" \) ;} $table_info -> index_1_table]} {
	regsub -all {,} $index_1_table {} index_1_elements
    puts "\ninput transition : $index_1_elements"
} else {
    puts "$table_info not found."
}


if {[regexp {index_2\( "(.*?)" \) ;} $table_info -> index_2_table]} {
	regsub -all {,} $index_2_table {} index_2_elements
    puts "output capacitance : $index_2_elements"
} else {
    puts "$table_info not found."
}


#______________________________________________________________________________________________________________________________________________________#
#Processing__________________________________________________________________________________________________________________________________________________#

set transition_index [lsearch $index_1_elements $inTran]
set capacitance_index [lsearch $index_2_elements $outCap]


if {$transition_index != -1 && $capacitance_index != -1} {
	puts "input transition & output capacitance exists in LUT"
	set sum 0
	set counter 0
	foreach table_result $pattern_table {
	set sum [expr $sum + [lindex [lindex $table_result $transition_index] $capacitance_index]]
	set counter [expr $counter+1]
	}
	set Prop_delay [expr $sum/$counter]
	set status "matching happened"	


} else {
	puts "extrapolation or interpolation happened"	
	set sum 0
	set counter 0
	
	set x1 [lindex $index_1_elements 0]
	set x2 [lindex $index_1_elements end]
	set y1 [lindex $index_2_elements 0]
	set y2 [lindex $index_2_elements end]
	
    foreach table_result $pattern_table {
	set T11 [lindex [lindex $table_result 0] 0]
	set T12 [lindex [lindex $table_result 0] end]
	set T21 [lindex [lindex $table_result end] 0]
	set T22 [lindex [lindex $table_result end] end]
	
	set x01 [expr ($inTran-$x1)/($x2-$x1)]
	set x20 [expr ($x2-$inTran)/($x2-$x1)]
	set y01 [expr ($outCap-$y1)/($y2-$y1)]
	set y20 [expr ($y2-$outCap)/($y2-$y1)]
	
	set delay_point [expr ($x20)*($y20)*($T11)+($x20)*($y01)*($T12)+($x01)*($y20)*($T21)+($x01)*($y01)*($T22)]	
	set sum [expr $sum + $delay_point]
	set counter [expr $counter+1]
	}
	set Prop_delay [expr $sum/$counter]
	set status "interpolation or Extrapolation happened"	
}
puts "status:$status" 

# write Cell Information in output file
set output_file "cell infomation.txt"
set output_handle [open $output_file "w"]
puts $output_handle "$cell_info"
close $output_handle 

# write LUT in output file
set output_file "table infomation.txt"
set output_handle [open $output_file "w"]
puts $output_handle "$table_info"
close $output_handle 


# write Propagation Delay operation
set output_file "Propagation Delay Calculation.txt"
set output_handle [open $output_file "a"]

puts $output_handle "|------------------------------------------------------------------------------|"
puts $output_handle "Cell name		  	:	$cell_name"
puts $output_handle "Library 		  	:	$input_file"
puts $output_handle "input transition 	:	$inTran"
puts $output_handle "output capacitance	:	$outCap"
puts $output_handle "Propagation case  	:	$Rise_Fall"
puts $output_handle "propagation Delay  :	$Prop_delay"
puts $output_handle "propagation Status :	$status"
puts $output_handle "|------------------------------------------------------------------------------|"
close $output_handle
return "Calculated delay :$Prop_delay"
}

# Example usage of the procedure
set cellName "no4_x1"
set inputTransition 18.0
set outputCapacitance 0.9
set riseFall 0
set libraryFile "ssxlib013.lib.txt"

# Call the procedure with the provided parameters
set delayResult [calCellDelay $cellName $inputTransition $outputCapacitance $riseFall $libraryFile]

# Print the result
puts "\n $delayResult"