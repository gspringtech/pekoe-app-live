module namespace pekoe="http://www.gspring.com.au/pekoe";
(:http://www.w3.org/TR/xpath-functions-30/#func-format-date
    Also see date picture in XSLT 2.0 Programmers ref.
:)
declare variable $pekoe:aust-short-date := "[D01]-[M01]-[Y]";
declare variable $pekoe:aust-long-date := "[D1o] [MNn], [Y]";


declare function pekoe:aust-short-date ($d) {
    if ($d castable as xs:date) then format-date($d,$pekoe:aust-short-date)
    else if ($d castable as xs:dateTime) then format-dateTime($d,$pekoe:aust-short-date) 
    else ""
};
declare function pekoe:long-date ($d) {
    if ($d castable as xs:date) then format-date($d, $pekoe:aust-long-date)
    else if ($d castable as xs:dateTime) then format-dateTime($d, $pekoe:aust-long-date) 
    else ""
};

declare function pekoe:split-three($str) {
if ($str ne "") then (
let $last-three := substring($str, string-length($str) - 2)
let $first := substring($str, 1, string-length($str) -3)
return (pekoe:split-three($first),$last-three)
) else ()
};

(: TODO replace with format-number :)
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