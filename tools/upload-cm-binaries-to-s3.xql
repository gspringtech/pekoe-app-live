xquery version "3.0";
(: FIX THE FILENAMES FIRST - SEE DB/PEKOE/TENANTS/CM/TOOLS/fix-bad-filenames.xql :)
declare namespace s3="http://pekoe.io/s3";
import module namespace ps3="http://pekoe.io/pekoe-s3" at "/db/apps/pekoe/modules/s3-toc.xqm";

declare function local:fix-permissions() {
    let $state := doc('/db/pekoe/tenants/cm/tools/upload-state.xml')/upload-state
    let $current := $state/path[position() eq last()]/@name/string()
    
    for $f in collection($current)/s3:toc
    let $col := util:collection-name($f)
    let $doc := util:document-name($f)
    let $g := xmldb:get-group($col,$doc)
    let $uri := document-uri(root($f))
    return if ($g eq 'admin') then sm:chgrp($uri,'cm_staff') else ()
};

declare function local:completed-bundles($col) {
    for $job in collection($col)/*[@bundled][(status)[position() eq last()] eq "Complete"]
    let $job-folder :=  util:collection-name($job)
    let $count-binaries := count(xmldb:get-child-resources($job-folder)[not(ends-with(.,'.xml'))])
    return if ($count-binaries gt 0) then $job-folder else ()
};

declare function local:bundles-without-toc($col, $offset, $length) {
    let $bundles-with-files := local:completed-bundles($col)
    for $b in $bundles-with-files[position() = $offset to ($offset + $length)]
    return if (exists(collection($b)/s3:toc)) then () else $b
    
};

declare function local:empty-toc($col) {
    for $empty in collection($col)/s3:toc[empty(./*)]
    let $job-folder := util:collection-name($empty)
    let $count-binaries := count(xmldb:get-child-resources($job-folder)[not(ends-with(.,'.xml'))])
    return if ($count-binaries gt 0) then $job-folder else ()
};

(: DON'T UPLOAD AN ACTIVE JOB - all the GENERATED documents will go with it. :)
declare function local:all-bundles($col) {
    for $job in collection($col)/*[@bundled]
    return util:collection-name($job)
};

declare function local:move-bundle-files-to-s3($bundled-jobs) {
    let $config := ps3:config('/db/pekoe/tenants/cm')
    let $tenant-path := "/db/pekoe/tenants/cm"
    for $job in $bundled-jobs
    return ps3:upload-binaries-from-collection($config, $tenant-path, $job) 
    (: NOTE ************************** THIS UPLOADS EVERYTHING!!!! DON'T USE ON AN ACTIVE JOB ****************** NEED TO ADD A FILTER FOR PDF ONLY ************ :)
    (: Don't delete the binaries here. Do that later. The file might still be in use. :)
};

(:************* MEMORY CHECK ************** :)

declare function local:human-units($bytes) {
let $unit := if($bytes > math:pow(1024, 3)) then
(math:pow(1024, 3), "GB")
else if($bytes > math:pow(1024, 2)) then
(math:pow(1024, 2), "MB") else
(1024, "KB") return
format-number($bytes div $unit[1], ".00") || " " || $unit[2]
};

declare function local:memory-check() {
    <memory> <max>{local:human-units(system:get-memory-max())}</max> <allocated>
<in-use>{ local:human-units(
                    system:get-memory-total()
                    - system:get-memory-free()
                )
}</in-use> <free>{local:human-units(system:get-memory-free())}</free> <total>{local:human-units(system:get-memory-total())}</total>
</allocated> <available>{
            local:human-units( system:get-memory-max()
                - system:get-memory-total()
                - system:get-memory-free()
) }</available>
</memory>
};

(:************* FIX BINARY FILE NAMES BEFORE UPLOADING ************** :)



(: See upload-state.xml.
 : Next is 06. Names must be fixed FIRST 
 : Try to fix names and DELETE files before an INCREMENTAL backup.
 : 
 : *** REMEMBER to LOGIN and LOGOUT of Pekoe, this will fix the S3-TOC files which will be owned by admin
 : 
 : :)


declare function local:do-upload() {
    (: For this to be scheduled, it will need some state - the path and the offset :)
    let $state := doc('/db/pekoe/tenants/cm/tools/upload-state.xml')/upload-state
    let $current := $state/path[position() eq last()]
    
    
    let $max := xs:integer($current/@bundles)
    let $offset := xs:integer($current/next-offset[position() eq last()])
    let $base := $current/@name/string()
    return if ($offset lt $max) then
        let $bundled-jobs := local:bundles-without-toc($base,$offset, 9)
    (:    (local:completed-bundles($base))[position() = $offset to ($offset + 9)]:)
        (:let $bundled-jobs := (local:empty-toc($base))[position() = 1 to 10]:) (: Use this version if there are binary files not yet processed :)
        (:return $bundled-jobs:)
        let $r := local:move-bundle-files-to-s3($bundled-jobs)
        let $next := <next-offset>{if (($offset + 10) lt $max) then ($offset + 10) else $max}</next-offset>
        let $jobs := update insert <jobs>{$bundled-jobs}</jobs> into $current
        let $mem := local:memory-check()
        let $stored := update insert $mem into $current
        let $new-state := update insert $next into $current
        return 
            util:log-app("warn","pekoe.io",concat("Processed ", count($r), " files in bundles ",$offset, " to ", $offset + 9, " of ", $max, " ", $mem/available ))
        else (
            util:log-app("warn","pekoe.io", "FINISHED processing " || $base || " Now DELETE the binaries and fix permissions.")
            ,scheduler:delete-scheduled-job("upload-to-s3")
            )
};

declare function local:completed-bundles($col) {
    for $job in collection($col)/*[@bundled][(status)[position() eq last()] eq "Complete"]
    let $job-folder :=  util:collection-name($job)
    let $count-binaries := count(xmldb:get-child-resources($job-folder)[not(ends-with(.,'.xml'))])
    return if ($count-binaries gt 0) then $job-folder else ()
};

declare function local:new-path($path) {
    let $bundles-to-process := count(local:completed-bundles($path))
    let $state := doc('/db/pekoe/tenants/cm/tools/upload-state.xml')/upload-state
(:    let $current := $state/path[position() eq last()]:)
    let $path := <path name="{$path}" bundles="{$bundles-to-process}" ><next-offset>0</next-offset></path>
    let $update := update insert $path into $state
    return $path
};


(:1 Create a new path in upload-state - but don't do this in the scheduled job or it will go wrong:)
(: local:new-path('/db/pekoe/tenants/cm/files/jobs/2017/01'):)
(:2 :)
(:local:fix-names():)
(:3:)
(:local:do-upload():)
(: 4:)
local:fix-permissions()


(:local:memory-check():)

(: NOTE - Do the DELETE somewhere else in another script. DON'T LINK THEM :)

(:
    SOMETHING WENT WRONG. ** which is why I'm running this on 10 folders at a time, and checking the memory as I go
    There are TOCs without any contents! Might be something to do with the MEMORY USE
    Might be the gateway timeout. 
    
    BUT BUT BUT.
    I think this is okay. Sure - it shouldn't have happened.
    But the only files I'm going to delete are the ones listed in the TOC
    AND the only files listed in the TOC are the ones that returned SUCCESS from AWS S3
    
    So I can delete them. Phew.
    And just run the uploader again (selecting empty files)
    Phew.


:)