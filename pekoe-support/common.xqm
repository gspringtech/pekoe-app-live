module namespace pekoe="http://www.gspring.com.au/pekoe";

declare function pekoe:aust-short-date ($d) {
    if ($d castable as xs:date) then datetime:format-date($d,"dd-M-yyyy")
    else if ($d castable as xs:dateTime) then datetime:format-dateTime($d,"dd-M-yyyy") 
    else ""
};
declare function pekoe:long-date ($d) {
    if ($d castable as xs:date) then datetime:format-date($d,"dd MM yyyy")
    else if ($d castable as xs:dateTime) then datetime:format-dateTime($d,"dd MM yyyy") 
    else ""
};

declare function pekoe:split-three($str) {
if ($str ne "") then (
let $last-three := substring($str, string-length($str) - 2)
let $first := substring($str, 1, string-length($str) -3)
return (pekoe:split-three($first),$last-three)
) else ()
};

declare function pekoe:currency($any-val) {
if (not($any-val castable as xs:decimal)) then concat("NaN(",$any-val,")") else 

let $val := if ($any-val castable as xs:decimal) then xs:decimal($any-val) else number("NaN")
let $is-negative := $val lt 0.0
let $as-cents := abs($val) * 100.0 (: MUST have the decimal 0 otherwise $val is converted to integer before multiplication :)
let $cents := $as-cents mod 100
let $dollars := $as-cents idiv 100
let $cents-string := if ($cents lt 10) then concat("0",$cents) else string($cents)
let $int := if (exists($dollars)) then string-join(pekoe:split-three(string($dollars)),",") else "0"

return 
if ($is-negative) 
then concat("-$",string($int),".",$cents-string) 
else concat( "$",string($int),".",$cents-string)

};