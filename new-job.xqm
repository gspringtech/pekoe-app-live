xquery version "3.1";
module namespace job="http://pekoe.io/pekoe/new-job";

import module namespace rp = "http://pekoe.io/resource-permissions"      at "xmldb:exist:///db/apps/pekoe/modules/resource-permissions.xqm";
import module namespace tenant = "http://pekoe.io/tenant"                at "xmldb:exist:///db/apps/pekoe/modules/tenant.xqm";
import module namespace sn="http://gspring.com.au/pekoe/serial-numbers"  at "xmldb:exist:///db/apps/pekoe/modules/serial-numbers.xqm";

declare variable $job:doctype := request:get-parameter("doctype", ());

declare variable $job:config := map {
    'save-fn' : job:save#1,
    'id-fn' : function ($config) { sn:get-next-padded-id($config) },
    'id-number-picture' : '000000',
    'id-prefix' : '',
    'new-fn': job:new#1,
    'new-path-fn' : job:bundle-path#2 , (: this can be replaced by the other new-path-fn below, or with a custom function :)
    'get-job-fn' : function ($config, $id) { 
        error(QName('http://pekoe.io/err', 'JobFnReq'), 'Missing get-job-fn') 
        },   (: This one must be replaced. :)
    'item-id-name' : $job:doctype, 
    'doctype' :      $job:doctype, 
    'path-to-me' :   "/exist/pekoe-files" || substring-after(request:get-servlet-path(),$tenant:tenant-path)
    };
    

(: ------------------------------------------------  MAIN FUNCTION --------------------------------------- :)
declare function job:process($config as map(*)) {
    if (request:get-method() eq 'POST') then  $config?save-fn($config)
    else
        switch (request:get-parameter('action',''))
        case "capture" return job:capture($config)
        case "release" return job:release($config)
        default return <result status='error'>Unknown action</result>
};


(: -----------------  new-path-fn -------------------------------------------------------------------------:)
(: Use one of these or your own custom file-path function. It should return a path and a data-file-name :)
declare function job:bundle-path($config, $id) {  (: --------------  This is a "BUNDLE" path - Create a collection named with the job-id in which to store the data.xml :)
    map { 
        'path' : concat( format-date(current-date(),"[Y]/[M01]") , '/' , $id), 
        'data-file-name' : "data.xml" 
        }
};

declare function job:direct-year-month-path($config, $id) { (: ------------- This is a "FILE" path - Create a file named with the job-id  :)
    map { 
        'path' :  format-date(current-date(),"[Y]/[M01]"),
        'data-file-name' :    $id || ".xml"
        }
};



declare function job:capture($config as map(*)) { (: this is a guard for job:new :)
    response:set-header("Content-type","text/xml"),
    util:declare-option("exist:serialize", "method=xml media-type=text/xml"),
    let $id := request:get-parameter("id",())
    return 
        if ($id eq "new") 
        then ($config?new-fn($config)) 
        else 
           <result status='fail'>Can't capture {$id} here</result>
};

declare function job:new($config as map(*)) {
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
            element id {$id}
        }
    )
};

(:  Save only applies to new jobs. Save is a POST. SAVE IS ONLY USED BY NEW JOBS. Save is only used by NEW jobs. ALL OTHERS GO THROUGH resource-management.xql 
    Save uses the id to create a new file. It sets the Location to the path of this new file.
    BUT I'm not really sure why this can't be handled by the resource-manager.
    
    ************** THIS WHOLE FUNCTION CAN BE REPLACED BY YOUR OWN CUSTOM SAVE FUNCTION.  ************* :)
    
declare function job:save($config) {
     let $id := request:get-parameter("id",()) 
     let $data := request:get-data()
     
     let $new-path-map := $config?new-path-fn($config, $id) 
     let $good-collection := rp:create-collection($config?collection-path, $new-path-map?path)
     
     (: this is where a file-write should happen - storing the previous version to the file-system. Or other Version Control :)
     
     let $stored := xmldb:store($good-collection, $new-path-map?data-file-name, $data)
     let $permissions : = sm:chmod(xs:anyURI($stored), $rp:open-for-editing)
     
     let $quarantined-path := "/exist/pekoe-files" || substring-after($stored, $tenant:tenant-path)
     return (response:set-status-code(201), (: "Created". Changing the location means this job will be 'released' by the resource-manager - NOT the original query. :)
        response:set-header("Location", $quarantined-path),
        <result status='okay' path='{$stored}'>Saved item {$id}</result>
        )
};

    (:
    NEW is called by capture. 
    The reason is that PekoeFile is simply calling "Membership.xql?id=new&action=capture"
    The Controller sees the .xql and passes this to the membership query - ignoring the capture.
    (this) Membership responds with a generated "member" element containing a new ID.
    The form is displayed (with a name "New Member")
    If the user Closes without Saving, PekoeFile calls "membership.xql?id=9&action=release" WITH NO DATA (it's a GET)
    At this point, the file hasn't been created. release sees empty($job) and so sn:return($config?item-id-name, $id) 
    IF the user chooses Save, this is a POST to Membership.xql?id=9
    The POST-handler below is called to create the new file.
    
    "new" MUST be done here, because RELEASE without a SAVE must also come here.    
    :)


declare function job:release($config) {       (:  THIS ONLY APPLIES to NEW Jobs. It should only be called if the job has not been saved.:)
    let $id := request:get-parameter("id",())
    let $job := $config?get-job-fn($config, $id)
    return 
        if (exists($job)) then (: This should be an error. :)
            let $job-file := document-uri(root($job))
            return rp:release-job($job-file)
        else sn:return($config?item-id-name, $id)
};


