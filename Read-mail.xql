
declare namespace mail="http://exist-db.org/xquery/mail";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "html5";
declare option output:media-type "text/html";


import module namespace lw="http://pekoe.io/list/wrapper" at "/db/apps/pekoe/list.xqm";
import module namespace tenant = "http://pekoe.io/tenant" at "xmldb:exist:///db/apps/pekoe/modules/tenant.xqm";
import module namespace pqt="http://gspring.com.au/pekoe/querytools" at "xmldb:exist:///db/apps/pekoe/modules/querytools.xqm";
import module namespace rp="http://pekoe.io/resource-permissions" at "xmldb:exist:///db/apps/pekoe/modules/resource-permissions.xqm";

(: A little confusing. Incoming mail will be mail:message, but 'created' will be mail. :)
declare variable $local:doctype := 'mail'; 

declare variable $local:collection := request:get-parameter('collection','dead-letters');
declare variable $local:items := collection($tenant:tenant-path || '/' || $local:collection)/mail:message;

declare function local:clean-subject($s) {
    let $code-regex := '^(rt|tx) \d+ (m|a).+'
    let $replace-regex := '^(rt|tx) \d+ (m|a)'
    return if (matches($s,$code-regex,'i')) then replace($s, $replace-regex,'', 'i') else $s/string()
};

if ($lw:action eq 'view') then
(
let $message := doc(request:get-parameter('message',''))/mail:message
let $sent := $message/mail:sent
let $from-name := $message/mail:from/string(@personal)
let $addr := $message/mail:from/string()
let $subject := encode-for-uri($message/mail:subject)
return 
<html><head><title>Read Mail</title>
<style type='text/css'> /* <![CDATA[ */
pre {
    white-space: pre-wrap; 
    width: 800px;
}
/* ]]> */
</style>
</head><body>
 <a href='javascript:history.back()'>Go back</a>
 <h1>Subject: {$message/mail:subject/string()}</h1>
 <h3>Sent: {if ($sent castable as xs:dateTime) then format-dateTime($sent, "[FNn], [D1o] [MNn] at [h].[m01][Pn]") else "???"}</h3>
 <h3>From: {if ($from-name) then $from-name else $addr}</h3>
 <h4><a href='mailto:{$addr}?subject={$subject}&amp;cc=pekoe@conveyancingmatters.com.au'>Reply</a></h4>
 { for $t in $message/mail:text return <pre>{string($t)}</pre> }
 { for $t in $message/mail:xhtml return <div>{$t/html/body/*}</div> }
 </body></html>
 )
else 
(: To begin coding this page, I copied from Tabular-data. But it's not boilerplate code - everything needs to be modified.
Also, something like AD-Bookings is a better model. :) 
(:let $log := util:log('warn','RMAIL collection ' || $tenant:tenant-path || $local:collection) :)
let $conf := map {
    'doctype' : function ($item) { $local:doctype } ,
    'display-title' : function ($item) {  $item/mail:subject/string() }
    }
    
let $default-content := lw:configure-content-map($conf)

let $content :=  map:new(($default-content,  map {
    'title' : 'Read Mail',
    'column-headings': ['Date', 'From', 'Subject','Comments','Mail'], 
    'path-to-me' : '/exist/pekoe-app/Read-mail.xql',
    'hidden-menus' : map:new(($default-content?hidden-menus, map {'delete': false()})),    
    'row-attributes' : function ($item, $row-data) {
        (: Produce a sequence of TR attributes        :)
            (attribute title {util:document-name($item)}, 
            attribute class {'mail'},
            attribute data-title {substring($item/mail:subject/string(), 1, 30)}, 
            attribute data-href {'/exist/pekoe-app/Read-mail.xql?action=view&amp;message=' || base-uri($item) },
            attribute data-path {substring-after(document-uri($item),$tenant:tenant-path)},
            attribute data-type {'other'})
    },
    'doctype' : $local:doctype,
    'fields' : map {
        'Date' : map {
            'value':function($message, $row-data) {
                let $sent := $message/mail:sent
                return if ($sent castable as xs:dateTime) then format-dateTime($sent, "[FNn], [D1o] [MNn] at [h].[m01][Pn]") else "???"
            },
            'sort-key' : 'rec',
            'sort' : function ($direction, $items) {
                if ($direction eq 'ascending') 
                then for $item in $items order by $item/mail:sent ascending return $item 
                else for $item in $items order by $item/mail:sent descending return $item }
        },
        'From' : map {
            'value':function($message, $row-data) {
                let $from-name := $message/mail:from/string(@personal)
                let $addr := $message/mail:from/string()
                let $subject := encode-for-uri(local:clean-subject($message/mail:subject))
                
                return <a href='mailto:{$addr}?subject={$subject}'>{if ($from-name) then $from-name else $addr}</a>
            }
        },
        'Subject' : map {
            'value':function($message, $row-data) {
              $message/mail:subject/string()
            }
        },
        'Comments' : map {
            'value':function($message, $row-data) {
              $message//rejection/string()
            }
        },
        'Mail' : map {
            'value':function($message, $row-data) {
              <a href='message:http://cm.pekoe.io/exist/rest{base-uri($message)}'>read in Mail app</a>
            }
        }
    },
        
   
    
    'order-by' : request:get-parameter('order-by','descending-rec'),
    'items' :  switch ($lw:action) 
    
                case "List" return $local:items
                case "Search" return $local:items[contains(., request:get-parameter('search',''))]
                case "xpath" return lw:xpath-search($local:items)
                default return $local:items
                
})) (: end of map:new :)

return lw:list-page($content)