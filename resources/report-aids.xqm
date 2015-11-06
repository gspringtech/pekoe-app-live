xquery version "3.1";

module namespace pr="http://pekoe.io/reports/aids";

(: This is useful for when iterating. :)
declare variable $local:months := ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');

declare function pr:start-of-month($date) as xs:date {
  $date - xs:dayTimeDuration("P" || day-from-date($date) - 1 || "D")
};

declare function pr:end-of-month($date) {
    pr:start-of-month($date) + xs:yearMonthDuration('P1M') - xs:dayTimeDuration('P1D')
};

declare function pr:last-of-month-str($date) {
    format-date(pr:end-of-month($date), '[Y0001]-[M01]-[D01]')
};

(: Not sure why I want two of each - but this one is probably fastest. :)
declare function pr:first-of-month-str($date) {
    format-date($date,'[Y0001]-[M01]-01')
};

declare function pr:fy-start($date) {
    if (month-from-date($date) le 6) 
    then xs:date(year-from-date($date) - 1 || '-07-01') 
    else xs:date(year-from-date($date) || '-07-01')
};
