module namespace site = "http://gspring.com.au/pekoe/site-tools";

(: 
A module for managing site specific details 
:)
(:
    Custom tools for _this_ site. Most, this is for the Merge Results. I have added some Output funtions at the end (e.g. site:format-notes() )
    
    These functions will be called (among other things) by 
    the MERGE - where the final step _could_ be site-specific. 
    
 
    
    
:)
(:~ function local:stream-result($template-file as item()*, $job as item()*, $merged-contents) :)
declare function local:stream-result($template-file, $job, $merged-contents) {
    
    let $mime := xmldb:get-mime-type(xs:anyURI($template-file))
    let $new-fn := local:make-file-name($job, $template-file)
    let $header :=  response:set-header('Content-disposition', concat('attachment; filename=',$new-fn))
    return response:stream-binary($merged-contents,$mime)
};

(:
This works but only for DBA. I don't want to give the caller of this module DBA privileges.

import module namespace af = "http://pekoe.io/fs/associated-files" at '/db/apps/pekoe/modules/fs-job-storage.xqm';

declare function local:save-in-job-folder($job, $template, $merged-content) {
    let $template-doc-name := local:make-file-name($job,$template)
    let $stored := af:write-file-to-job-folder($job, $template-doc-name, $merged-content)
    return <result>{$stored}</result>
};:)

declare function local:save-in-job-folder($job, $template, $merged-content) {
    let $job-path := util:collection-name($job)
(:  If the collection name is the same as the job name, then it's the job folder. 
    But if it's not, then create a new collection using the job-name.
    How could this go wrong?
    No permission.
    Too many folders?
    Collection name isn't the same as the job-name because of some other reason?
    Two cases:
    2014/01/Tx-09745.xml
    2015/07/RT-000020/data.xml
:)
(:    let $current-user := util:log-app('info','login.pekoe.io', 'CURRENT USER IN MERGE IS ' || sm:id()//sm:username):)
    let $job-folder := util:collection-name($job)
    let $template-doc-name := local:make-file-name($job,$template)
    let $stored := xmldb:store($job-folder,$template-doc-name,$merged-content)
    return <result>{$stored}</result>
    
};

declare function local:make-file-name($job, $template-file) {
    (: it doesn't need the job id if we're storing it in the job! :) 
    let $fileName := tokenize($template-file,"/")[position() eq last()]
    let $fn-parts := tokenize($fileName, "\.")
    let $job-id := $job/*/string(our-ref)
(:    let $fn := concat($fn-parts[1], "-",$job-id, "-",replace(current-dateTime(), "-|T.*$",""),".",$fn-parts[2]):)
    let $fn := concat($fn-parts[1], "-",$job-id,".",$fn-parts[2])
    return $fn
};

(:~  
 @param $job as element
 @param $template
  @param $merged-content
  :)
declare function site:delivery($job, $template as xs:string, $merged-content) {
    let $action := request:get-parameter("action","")
    return 
    if ($action eq "download") 
        then local:stream-result($template, $job, $merged-content)
    else if ($action eq "save-in-job-folder") 
        then local:save-in-job-folder($job,$template, $merged-content)
    else if ($action eq "email") then
(:   INSTEAD OF ATTACHING THE JOB, WHY NOT ATTACH function which sets the job's 'sent-date' using a closure!!!!  :)
        request:set-attribute("mail-map", map { "mail" := $merged-content, "job":= $job, "template" := $template})
    else ()
        
};


