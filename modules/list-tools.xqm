xquery version "3.0";
module namespace lt="http://pekoe.io/list-tools";

declare function lt:fy($in-d) {
    if ($in-d castable as xs:date) then
        let $d := if ($in-d instance of xs:date) then $in-d else xs:date($in-d)
        return if (month-from-date($d) lt 7) then year-from-date($d) - 1 else year-from-date($d)
  else ()
};