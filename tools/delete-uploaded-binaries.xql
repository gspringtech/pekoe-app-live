xquery version "3.1";

(:Process...
    1 - Rename the files in the month-folder using fix-bad-filenames in tenants/cm/tools
    3 - Run upload-cm-binaries in BATCHES of 10 (choosing the same folder as above) 
    3 - Delete these when all batches are finished.
    4 - RESTART the DB
    
    ********** Will also want to find any binaries left in folders containing a TOC.
:)

declare namespace s3="http://pekoe.io/s3";

declare function local:completed-bundles($col) {
    for $job in collection($col)/*[@bundled][(status)[position() eq last()] eq "Complete"]
    return util:collection-name($job)
};

(: I should be able to select any TOC in the year, and then delete the files listed in it. Deleting something that doesn't exist should be okay. :)
let $col := '/db/pekoe/tenants/cm/files/jobs/2017/01'
for $toc in collection($col)/s3:toc
    let $toc-col := util:collection-name($toc)
    for $f in $toc/s3:file
    let $is-available := util:binary-doc-available($toc-col || '/' || $f/string())
    let $remove := if ($is-available) then 
(:    ():)
    xmldb:remove($toc-col, $f/string()) 
    else ()
    return if ($is-available) then concat("removed ", $toc-col, '/', $f/string()) else ()
(:        concat($toc-col, '/', $f, " NOT REMOVED"):)
    