xquery version "3.1";

import module namespace tenant = "http://pekoe.io/tenant"                at "xmldb:exist:///db/apps/pekoe/modules/tenant.xqm";
import module namespace rp = "http://pekoe.io/resource-permissions"      at "xmldb:exist:///db/apps/pekoe/modules/resource-permissions.xqm";
import module namespace ps3="http://pekoe.io/pekoe-s3"                   at "xmldb:exist:///db/apps/pekoe/modules/s3-toc.xqm";

declare namespace s3 = "http://pekoe.io/s3";

(: ******* SEE $job:config for DEFAULTS and OVERRIDE options. ******* :) 
import module namespace job="http://pekoe.io/pekoe/new-job"              at "xmldb:exist:///db/apps/pekoe/new-job.xqm";

declare variable $local:doctype := request:get-parameter('doctype','');
declare variable $local:job-path := '/db/pekoe/tenants/cm/files/jobs';
declare variable $local:action := request:get-parameter("action",'new');
declare variable $local:conversions := doc('/db/pekoe/tenants/cm/files/resources/conversions.xml')//property;

declare variable $local:common := map:new(($job:config,
    map {
    'item-id-name' : $local:doctype, 
    'id-number-picture' : '000000',
    'new-fn' : local:new#1,
    'save-fn' : local:save-with-s3#1,
    'doctype' :      $local:doctype, 
    'path-to-me' :   "/exist/pekoe-files" || substring-after(request:get-servlet-path(),$tenant:tenant-path),
    'collection-path' : $tenant:tenant-path || '/files/jobs' (: Same for all job-types at the moment. :)
    }));

declare variable $local:residential := map:new(($local:common, 
    map {
            'item-id-name' : 'rt', (: This is the identifier in the serial-numbers collection - it will be the file-name and used like <serial-numbers for='rt'>... :)
            'id-prefix' : 'RT-',   (: a prefix before the number :)
            'get-job-fn' : function ($config, $id) { collection($local:job-path)/residential[our-ref eq $id] }            (: This function is used to confirm that the job exists - in case the user Cancels saving. :)
        }
        ));
        
declare variable $local:agency := map:new(($local:common, 
    map {
            'item-id-name' : 'ax',
            'id-prefix' : 'Ax-',
            'get-job-fn' : function ($config, $id) {collection($local:job-path)/agency[our-ref eq $id]}            
        }));

declare variable $local:business := map:new(($local:common, 
    map {
            'item-id-name' : 'bu',
            'id-prefix' : 'BU-',
            'get-job-fn' : function ($config, $id) {collection($local:job-path)/business[our-ref eq $id]}            
        }));

declare variable $local:searches := map:new(($local:common, 
    map {
            'item-id-name' : 'sx',
            'id-prefix' : 'Sx-',
            'get-job-fn' : function ($config, $id) {collection($local:job-path)/searches[our-ref eq $id]}            
        }));
        
declare variable $local:public-trustee := map:new(($local:common, 
    map {
            'item-id-name' : 'pt',
            'id-prefix' : 'PT-',
            'get-job-fn' : function ($config, $id) {collection($local:job-path)/public-trustee[our-ref eq $id]}            
        }));
        
declare variable $local:land-division := map:new(($local:common, 
    map {
            'item-id-name' : 'ld',
            'id-prefix' : 'LD-',
            'get-job-fn' : function ($config, $id) {collection($local:job-path)/land-division[our-ref eq $id]}            
        }));  
        
declare variable $local:legal := map:new(($local:common, 
    map {
            'item-id-name' : 'legal',
            'id-prefix' : 'LE-',
            'get-job-fn' : function ($config, $id) {collection($local:job-path)/land-division[our-ref eq $id]}            
    }));
    
declare variable $local:lease := map:new(($local:common, 
    map {
            'item-id-name' : 'ls',
            'id-prefix' : 'LS-',
            'get-job-fn' : function ($config, $id) {collection($local:job-path)/lease[our-ref eq $id]}            
    }));
    
declare variable $local:enquiry := map:new(($local:common, 
    map {
            'collection-path' : $tenant:tenant-path || '/files/enquiries', (: NOTE this is an override of the default above:)
            'item-id-name' : 'enq',
            'id-prefix' : 'Enq-',
            'get-job-fn' : function ($config, $id) {collection('/db/pekoe/tenants/cm/files/enquiries')/enquiry[our-ref eq $id]}   
    (:  ******** NEED to OVERRIDE the new-fn here so that the default provides status=prospective ***          :)
    }));
    
declare variable $local:issue := map:new(($local:common, 
    map {
            'collection-path' : $tenant:tenant-path || '/files/issues',
            'get-job-fn' : function ($config, $id) {collection('/db/pekoe/tenants/cm/files/issues')/issue[id eq $id]}            
    }));

(:
    This will create a simple element with appropriate date and user attributes and an ID and store it somewhere.
    It contains recipies for each of the CM job-types.
    
    HOW is this CALLED?
    The 'New xxx' button generated by the List module has this href:
    data-href='{$conf?doctype}:/exist/pekoe-files/config/new-job.xql?id=new'
    which is translated to a tenant-path. So _this_ file is REQUIRED.
    
    SO - is it possible to customise this?
    
    data-href='{$conf?doctype}:/exist/pekoe-files/config/new-job.xql?id=newFromEnquiry&enquiry=/path/to/enquiry
    I think the key difference is that we're going to SAVE the file and return the LOCATION.
    
    THIS is what the 'Convert-to-Job' function expects as a result
    
            let $href := 'residential:/exist/pekoe-files/files/jobs/2015/02/Tx-12351.xml'
            return (
                response:set-status-code(201), 
                response:set-header('Location',$href), 
                <result>Converted to {$doc//transaction-type/string()}</result>
            )
----------------->>>>>>
The key is to sidestep the job:process function - that's the one that normally handles the action.
It should be possible. 
<<<<<<<<<-------------

:)


(: This doesn't create a file in the DB. That's the SAVE function - which can be overridden.  :)
(:  *** This is a CUSTOM new-job function. It creates a CM-specific Job. It receives the config created below. :)
declare function local:new($config as map(*)) {
    let $id := $config?id-fn($config)
    let $new-path :=  $config?new-path-fn($config, $id) 
    let $quarantined-path := "/exist/pekoe-files" || substring-after($new-path?path, $tenant:tenant-path)
    let $created-by := sm:id()//sm:real/sm:username/text()
    
    return 
    (   response:set-status-code(201), (: "Created" :)
        response:set-header("Location", $config?path-to-me || "?id=" || $id || "&amp;doctype=" || $config?doctype), (: The path remains the same with the addition of the id parameter. This allows the user to Close without Saving - and the ID can be recycled. :)

        element {$config?doctype} {
            attribute created-dateTime {current-dateTime()},
            attribute created-by {$created-by},
            attribute bundled {1},
            element our-ref {$id}
        }
    )
    (: ******** Notice "our-ref" above. This is the reason for a local version of this function. What a shame. 
    ** ENQUIRY:
    I could almost modify this function for the newFromEnquiry.
    The difference is the element constructor
    
    :)
};

(:  Override the Save function (where a file is actually stored in the DB.) 
    This version will create the S3:TOC so that any uploads go to S3
:)
declare function local:save-with-s3($config) {
     let $id := request:get-parameter("id",()) 
     let $data := request:get-data()
     
     let $new-path-map := $config?new-path-fn($config, $id) 
     let $good-collection := rp:create-collection($config?collection-path, $new-path-map?path)
     
     (: this is where a file-write should happen - storing the previous version to the file-system. Or other Version Control :)
     
     let $stored := xmldb:store($good-collection, $new-path-map?data-file-name, $data)
     let $owner := sm:id()//sm:real/sm:username/string()
     let $chown := sm:chown(xs:anyURI($stored), $owner )
     let $permissions : = sm:chmod(xs:anyURI($stored), $rp:open-for-editing)
     
     let $s3-toc := ps3:create-toc($good-collection) (: Permissions ? :)    
     
     let $quarantined-path := "/exist/pekoe-files" || substring-after($stored, $tenant:tenant-path)
     return (response:set-status-code(201), (: "Created". Changing the location means this job will be 'released' by the resource-manager - NOT the original query. :)
        response:set-header("Location", $quarantined-path),
        <result status='okay' path='{$stored}'>Saved item {$id}</result>
        )
};



(:
    newFromEnquiry
    given the path to an Enquiry
    
    - get the transaction doctype (from 'conversions' - possibly unnecessary)
    - get the appropriate local config for that type
    - get a stylesheet suitable for the transaction-type
    - transform to Job
    - save the new Job (and fix permissions)
    - return the path to the new job
:)

(: 
    This function is activated by the "Create Job" command-button on the /enquiry/new-job-ref field.
    
    CONSIDER the possibiblity of generating the new job WITHOUT SAVING. This would allow the user to CANCEL.
    This would be much more like the id=new version - but the generated element would be different.
:)
declare function local:newFromTTButton() { (: The Transaction-type command button. :)
    let $enquiry-id := request:get-parameter('id','')
    let $doc := collection('/db/pekoe/tenants/cm/files/enquiries')//our-ref[. eq $enquiry-id]/..
    let $tt := $doc//transaction-type/string()
    let $toc := xmldb:xcollection(util:collection-name($doc))/s3:toc
    
    let $new-type := $local:conversions[value eq $tt]/string(@name) (: 'residential' - this will be needed to get the CONFIG MAP  :)
    
    (: This is not getting a result - yet 
        enq-id 'Enq-000037' 'Residential-Purchaser' new-type ''    :)
    let $check2 := util:log('warn',"enq-id '" || $enquiry-id ||  "' '" || $tt || "' new-type '" || $new-type || "'")
    
    let $config := switch ($new-type)
        case "residential"  return $local:residential
        case "agency"       return $local:agency
        default             return error((),'Missing new transaction type')
    
    let $job-id := $config?id-fn($config)
    let $job-path :=  $config?new-path-fn($config, $job-id)
    let $owner := sm:id()//sm:real/sm:username/string()

    (: The selected stylesheet will be based on the transaction-type - NOT the more general DOCTYPE    :)
    
    let $ss := switch ($tt) 
        case "Residential-Purchaser"    return 'conversions/residential-purchaser.xsl'
        case "Residential-Vendor"       return 'conversions/residential-vendor.xsl'
        default                         return 'conversions/residential-purchaser.xsl'
        
    let $params := 
        <parameters>
            <param name='user' value='{$owner}' />
            <param name='job-id' value='{$job-id}' />
            <param name='client-id' value='' />
        </parameters>
        
    let $new-job := transform:transform($doc,doc($ss),$params)
    
    let $good-collection := rp:create-collection($config?collection-path, $job-path?path)
     
    (: this is where a file-write should happen - storing the previous version to the file-system. Or other Version Control :)
    
    let $stored := xmldb:store($good-collection, $job-path?data-file-name, $new-job)    
    let $chown := sm:chown(xs:anyURI($stored), $owner )
    let $permissions : = sm:chmod(xs:anyURI($stored), $rp:open-for-editing)
    
    (: ***************  Copy the TOC from Enquiry to Residential. No need to move the files - just add this TOC. Does it work? Are there any issues? ********   :)
    let $copied-toc := if(empty($toc)) then () else xmldb:store($good-collection, $ps3:default-toc-name, $toc)

    let $new-quarantined-path := "/exist/pekoe-files" || substring-after($stored, $tenant:tenant-path)

    let $href := $new-type || ':' || $new-quarantined-path
    return (
        response:set-status-code(201), 
        response:set-header('Location',$href), 
        <result>{$job-id}</result>
    )

};

declare function local:new-from-search-TT() { (: The Transaction-type command button. :)
    let $enquiry-id := request:get-parameter('id','')
    let $doc := collection('/db/pekoe/tenants/cm/files/jobs')//our-ref[. eq $enquiry-id]/..
    let $tt := $doc//transaction-type/string()
    let $toc := xmldb:xcollection(util:collection-name($doc))/s3:toc

    let $new-type := 'residential' 
    (:    $local:conversions[value eq $tt]/string(@name) (\: 'residential' - this will be needed to get the CONFIG MAP  :\):)
    
    let $config := $local:residential
    
    let $job-id := $config?id-fn($config)
    let $job-path :=  $config?new-path-fn($config, $job-id)
    let $owner := sm:id()//sm:real/sm:username/string()

    (: The selected stylesheet will be based on the transaction-type - NOT the more general DOCTYPE    :)
    
    let $ss := 'conversions/search-to-vendor.xsl'
        
    let $params := 
        <parameters>
            <param name='user' value='{$owner}' />
            <param name='job-id' value='{$job-id}' />
            <param name='client-id' value='' />
        </parameters>
        
    let $new-job := transform:transform($doc,doc($ss),$params)
    
    let $good-collection := rp:create-collection($config?collection-path, $job-path?path)
     
    (: this is where a file-write should happen - storing the previous version to the file-system. Or other Version Control :)
    
    let $stored := xmldb:store($good-collection, $job-path?data-file-name, $new-job)
    let $chown := sm:chown(xs:anyURI($stored), $owner )
    let $permissions : = sm:chmod(xs:anyURI($stored), $rp:open-for-editing)
    let $new-quarantined-path := "/exist/pekoe-files" || substring-after($stored, $tenant:tenant-path)

    (: ***************  Copy the TOC from Search to Residential. No need to move the files - just add this TOC. 
    BUT BUT BUT - What if it's not there? Should TELL the user to Make one.
    :)
    let $copied-toc := if (empty($toc)) then () 
        else
        xmldb:store($good-collection, $ps3:default-toc-name, $toc)
    

    let $href := $new-type || ':' || $new-quarantined-path
    return (
        response:set-status-code(201), 
        response:set-header('Location',$href), 
        <result>{$job-id}</result>
    )

};

declare function local:copy-from-search-TT() { (: The Transaction-type command button. :)
    let $search-id := request:get-parameter('id','')
    let $rt-id := request:get-parameter('rtid','')
    let $this-search := collection('/db/pekoe/tenants/cm/files/jobs')/searches[our-ref eq $search-id]
    (: Only want to copy the search TOC to new toc   :)
    let $search-toc := xmldb:xcollection(util:collection-name($this-search))/s3:toc

    let $new-type := 'residential' 
    let $rt-job := collection('/db/pekoe/tenants/cm/files/jobs')/residential[our-ref eq $rt-id]
    let $rt-col := util:collection-name($rt-job)
    let $rt-toc := xmldb:xcollection($rt-col)/s3:toc
    let $quarantined-path := tenant:quarantined-path(util:collection-name($rt-job))
(: ***************  Copy the TOC from Search to Residential. No need to move the files - just add this TOC. Does it work? Are there any issues? ********   :)
(:    let $copied-toc := xmldb:store($good-collection, $ps3:default-toc-name, $toc):)
    
(:  Conditions
    No Search
    No Search TOC
    No RT
    No RT TOC
    Existing RT TOC
:)
    let $href := 'residential:' || $quarantined-path
    return
        if ($search-id eq '' or empty($this-search)) then (
            response:set-status-code(409), (: 409 Conflict in request params :)
            <result>There was a problem finding these Searches: {$search-id}</result>              
        )
        else if (empty($search-toc)) then (
            response:set-status-code(409), (: 409 Conflict in request params :)
            <result>There were no S3-uploaded Search documents to copy in {$search-id}</result> 
        )
        else if ($rt-id eq '' or empty($rt-job)) then (
            response:set-status-code(409), (: 409 Conflict in request params :)
            <result>There was a problem finding this Residential job: {$rt-id}</result> 
        )
        else if (empty($rt-toc)) then ( (: simply copy the search TOC into the RT :)
            xmldb:store($rt-col, $ps3:default-toc-name, $search-toc),
            response:set-status-code(201), 
            response:set-header('Location',$href), 
            <result>{$rt-id}</result>
        )
        else ( (: ADD the Search-toc/files to the RT-toc :)
            let $search-files := $search-toc/s3:file
            let $updated := update insert $search-files into $rt-toc
            return (response:set-status-code(201), 
            response:set-header('Location',$href), 
            <result>{$rt-id}</result>)
        
        )
};

(: --------------------------- MAIN QUERY -------------------------:)

if ($local:action eq 'newFromEnquiry') then <result status="error">No newFromEnquiry</result>
else if ($local:action eq 'newFromTTButton') then local:newFromTTButton()
else if ($local:action eq 'new-from-search') then local:new-from-search-TT()
else if ($local:action eq 'copy-from-search') then local:copy-from-search-TT()
else switch ($local:doctype)
    case "business"            return job:process($local:business)
    case "issue"            return job:process($local:issue)
    case "residential"      return job:process($local:residential)
    case "agency"           return job:process($local:agency)
    case "searches"           return job:process($local:searches)
    case "public-trustee"   return job:process($local:public-trustee)
    case "land-division"    return job:process($local:land-division)   
    case "legal"            return job:process($local:legal)   
    case "lease"            return job:process($local:lease)
    case "enquiry"          return job:process($local:enquiry)
    default return <result status='error'>Doctype {$local:doctype} not configured in new-job.xql</result>

(: The job:process function evaluates the request based on whether it's a POST==Save or Capture or Release
    For the 'newFromEnquiry' I need to use the 'capture' function - which is just a guard for $config:new-fn($config) 
    
:)
