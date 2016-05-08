xquery version "3.0";
(:import module namespace tenant = "http://pekoe.io/tenant" at "modules/tenant.xqm";:)
import module namespace merge="http://www.gspring.com.au/pekoe/merge" at "templates/merge-generators.xqm";

(:declare variable $local:action := request:get-parameter("action","");
declare variable $local:job := request:get-parameter("path","");:)

(:
        This file has setUid enabled
        
        Each schema has a module and each template has a merge query which imports that module.
        These are generated files which need to be owned by admin and <tenant>_staff readable but not writeable:
        admin : _staff rwxr_x---
        
        But the _admin users may need to edit the template files and regenerate the queries.
        
        I have been managing this with an automatic check on the dates of those files, 
        with an automatic regeneration of the files
        but this frequently leads to permissions issues.
        
        The alternatives:
            - only allow Admin to edit the files
            - make the permissions more lenient
            - set up a trigger
            - add a Common Command to both the Schema template and the Links template.
            - put the automated check in a pipeline from the controller.
            
        The advantage of the last option is that it will happen as required, and whenever one of the inputs changes.
        The disadvantage is that this step will be performed every time a merge is requested.
        Another disadvantage (which I've already encountered) is that changes to schema or templates may result 
        in an error which might not be seen immediately.
        
        The advantage of the Command approach is that I can make changes without anything happening.
        But when I do run the command, I should pick up any issues. (maybe not - I still need to test the merge)
        
        So I'll make this Command driven, but it could become automated.
        
        AND THE ONE MAJOR FLAW IN MY LINKS COMMAND IS THAT I DON'T KNOW THE ORIGINAL TEMPLATE.
        BECAUSE I'M LOOKING AT THE TEMPLATES-META .../links.xml
        
        THIS MEANS REVERTING TO THE ORIGINAL APPROACH - USING THE CONTROLLER - BUT AS A 
:)
(:let $real-path := tenant:real-path($local:job)
let $log := util:log('info','%%%%%%%%%%%% PATH ' || $real-path)
return 

switch ($local:action)
case "schema" 
    return merge:generate-xquery-module-for-schema(tenant:real-path($local:job))
case "template"
       return merge:update-merge(tenant:real-path($local:job), $tenant:tenant)
default return <result>Unknown action {$local:action}</result>:)

(:ALL THAT THIS QUERY DOES IS WRAP A SETUID AROUND THE ORIGINAL GET-LINKS-QUERY:)
(:    let $log := util:log('info','%%%%%%%%%%%% CHECK TEMPLATE ' || request:get-parameter('template',"")):)
    let $path := merge:update-links-query(request:get-parameter('template',""), request:get-parameter('tenant',''))
(:    let $attr := request:set-attribute('xquery.url',$path):)
    return $path
